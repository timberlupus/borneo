import 'dart:convert';

import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';

class NvsSettingEntry<T> {
  final String namespace;
  final String key;
  T _value;
  T _initialValue;
  final void Function() _notifyListeners;
  bool available;

  T get value => _value;
  bool get changed => available && _value != _initialValue;
  void setValue(T value) {
    _value = value;
    _notifyListeners();
  }

  void reset() {
    _value = _initialValue;
    _notifyListeners();
  }

  NvsSettingEntry(
    T initialValue,
    this._notifyListeners, {
    required this.namespace,
    required this.key,
    this.available = true,
  }) : _value = initialValue,
       _initialValue = initialValue;
}

class ChannelSettingsEntry {
  final int index;
  final void Function() _notifyListeners;
  final bool Function(String) _validateName;

  String _name;
  String _initialName;
  String _color;
  String _initialColor;

  String get name => _name;
  String get color => _color;
  bool get nameChanged => _name != _initialName;
  bool get colorChanged => _color != _initialColor;
  bool get changed => _name != _initialName || _color != _initialColor;
  bool get nameValid => _validateName(_name);

  ChannelSettingsEntry({
    required this.index,
    required String name,
    required String color,
    required void Function() notifyListeners,
    required bool Function(String) validateName,
  }) : _name = name,
       _initialName = name,
       _color = color,
       _initialColor = color,
       _notifyListeners = notifyListeners,
       _validateName = validateName;

  void setName(String value) {
    if (_name != value) {
      _name = value;
      _notifyListeners();
    }
  }

  void setColor(String value) {
    if (_color != value) {
      _color = value;
      _notifyListeners();
    }
  }

  void syncInitial() {
    _initialName = _name;
    _initialColor = _color;
  }
}

class ControllerSettingsViewModel extends BaseLyfiDeviceViewModel {
  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();

  late final int maxChannelCount;
  late final NvsSettingEntry<int> pwmFreq;
  late final NvsSettingEntry<bool> overpowerEnabled;
  late final NvsSettingEntry<int> overpowerCutoff;
  late final NvsSettingEntry<bool> overtempEnabled;
  late final NvsSettingEntry<int> overtempCutoff;
  late final NvsSettingEntry<int> channelCountSetting;

  late final List<ChannelSettingsEntry> _channels;
  List<ChannelSettingsEntry> get channels => _channels;

  bool get hasChanges {
    final basicChanged =
        pwmFreq.changed ||
        overpowerEnabled.changed ||
        overpowerCutoff.changed ||
        overtempEnabled.changed ||
        overtempCutoff.changed ||
        channelCountSetting.changed;
    final channelChanged = _channels.any((channel) => channel.changed);
    return basicChanged || channelChanged;
  }

  bool get canSubmit => hasChanges && _channels.every((channel) => channel.nameValid);

  String getChannelName(int index) => _channels[index].name;
  String getChannelColor(int index) => _channels[index].color;
  bool isChannelNameValid(int index) => _channels[index].nameValid;
  void setChannelName(int index, String value) {
    _channels[index].setName(value);
  }

  void setChannelColor(int index, String value) {
    _channels[index].setColor(value);
  }

  ControllerSettingsViewModel({
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
    required super.gt,
    required super.wotThing,
  });

  @override
  Future<void> onInitialize() async {
    await super.onInitialize();

    pwmFreq = NvsSettingEntry<int>(500, notifyListeners, namespace: "led", key: "pwmfreq");
    overpowerEnabled = NvsSettingEntry<bool>(true, notifyListeners, namespace: "protect", key: "opp.en");
    overpowerCutoff = NvsSettingEntry<int>(999999, notifyListeners, namespace: "protect", key: "opp.v");
    overtempEnabled = NvsSettingEntry<bool>(true, notifyListeners, namespace: "protect", key: "ot.en");
    overtempCutoff = NvsSettingEntry<int>(65, notifyListeners, namespace: "protect", key: "ot.v");

    // Initialize channel count setting from device info. Channel metadata is loaded from NVS.
    final info = super.lyfiDeviceInfo;
    channelCountSetting = NvsSettingEntry<int>(info.channelCount, notifyListeners, namespace: "led", key: "chcount");

    maxChannelCount = info.channelCountMax;

    await _initSetting(
      pwmFreq,
      () async => await this.borneoDeviceApi.getFactoryNvsU16(boundDevice!.device, pwmFreq.namespace, pwmFreq.key),
    );
    await _initSetting(
      overpowerEnabled,
      () async =>
          (await this.borneoDeviceApi.getFactoryNvsU8(
            boundDevice!.device,
            overpowerEnabled.namespace,
            overpowerEnabled.key,
          )) !=
          0,
    );
    await _initSetting(
      overpowerCutoff,
      () async => await this.borneoDeviceApi.getFactoryNvsI32(
        boundDevice!.device,
        overpowerCutoff.namespace,
        overpowerCutoff.key,
      ),
    );
    await _initSetting(
      overtempEnabled,
      () async =>
          (await this.borneoDeviceApi.getFactoryNvsU8(
            boundDevice!.device,
            overtempEnabled.namespace,
            overtempEnabled.key,
          )) !=
          0,
    );
    await _initSetting(
      overtempCutoff,
      () async =>
          await this.borneoDeviceApi.getFactoryNvsU8(boundDevice!.device, overtempCutoff.namespace, overtempCutoff.key),
    );
    await _initSetting(
      channelCountSetting,
      () async => await this.borneoDeviceApi.getFactoryNvsU8(
        boundDevice!.device,
        channelCountSetting.namespace,
        channelCountSetting.key,
      ),
    );

    final channelNames = List<String>.filled(maxChannelCount, '', growable: false);
    final channelColors = List<String>.filled(maxChannelCount, '#FFFFFF', growable: false);
    for (int channel = 0; channel < maxChannelCount; channel++) {
      channelNames[channel] = await _loadChannelNameFromNvs(channel);
      channelColors[channel] = await _loadChannelColorFromNvs(channel);
    }

    _channels = List<ChannelSettingsEntry>.generate(
      maxChannelCount,
      (i) => ChannelSettingsEntry(
        index: i,
        name: channelNames[i],
        color: channelColors[i],
        notifyListeners: notifyListeners,
        validateName: _validateChannelName,
      ),
      growable: false,
    );
  }

  String _defaultChannelName(int channel) => 'CH${channel + 1}';

  Future<String> _loadChannelNameFromNvs(int channel) async {
    final key = 'ch$channel.name';
    final fallback = _defaultChannelName(channel);
    try {
      final exists = await this.borneoDeviceApi.factoryNvsExists(boundDevice!.device, 'led', key);
      if (!exists) {
        return fallback;
      }

      final value = await this.borneoDeviceApi.getFactoryNvsString(boundDevice!.device, 'led', key);
      if (!_validateChannelName(value)) {
        return fallback;
      }
      return value;
    } catch (error, stackTrace) {
      super.logger?.w('Failed to read factory NVS led/$key: $error', error: error, stackTrace: stackTrace);
      return fallback;
    }
  }

  Future<String> _loadChannelColorFromNvs(int channel) async {
    final key = 'ch$channel.color';
    const fallback = '#FFFFFF';
    try {
      final exists = await this.borneoDeviceApi.factoryNvsExists(boundDevice!.device, 'led', key);
      if (!exists) {
        return fallback;
      }

      final value = await this.borneoDeviceApi.getFactoryNvsString(boundDevice!.device, 'led', key);
      if (value.trim().isEmpty) {
        return fallback;
      }
      return value;
    } catch (error, stackTrace) {
      super.logger?.w('Failed to read factory NVS led/$key: $error', error: error, stackTrace: stackTrace);
      return fallback;
    }
  }

  bool _validateChannelName(String value) {
    // Must be 1-15 bytes in UTF-8 and not all whitespace
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    try {
      final bytes = utf8.encode(value);
      return bytes.isNotEmpty && bytes.length <= 15;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initSetting<T>(NvsSettingEntry<T> setting, Future<T> Function() getter) async {
    try {
      if (await this.borneoDeviceApi.factoryNvsExists(boundDevice!.device, setting.namespace, setting.key)) {
        setting._value = await getter();
        setting._initialValue = setting._value;
        setting.available = true;
      } else {
        setting.available = false;
      }
    } catch (error, stackTrace) {
      setting.available = false;
      super.logger?.w(
        'factoryNvsExists failed for ${setting.namespace}/${setting.key}: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> submit() async {
    try {
      await doSubmit();
    } catch (error) {
      notification.showError("Failed to update controller settings", body: error.toString());
      // Optionally log the error if logging is available in BaseLyfiDeviceViewModel.
      rethrow;
    }
  }

  Future<void> doSubmit() async {
    if (pwmFreq.changed) {
      await this.borneoDeviceApi.setFactoryNvsU16(boundDevice!.device, pwmFreq.namespace, pwmFreq.key, pwmFreq.value);
      pwmFreq.reset();
    }

    if (overpowerEnabled.changed) {
      await this.borneoDeviceApi.setFactoryNvsU8(
        boundDevice!.device,
        overpowerEnabled.namespace,
        overpowerEnabled.key,
        overpowerEnabled.value ? 1 : 0,
      );
      overpowerEnabled.reset();
    }

    if (overpowerCutoff.changed) {
      await this.borneoDeviceApi.setFactoryNvsI32(
        boundDevice!.device,
        overpowerCutoff.namespace,
        overpowerCutoff.key,
        overpowerCutoff.value,
      );
      overpowerCutoff.reset();
    }

    if (overtempEnabled.changed) {
      await this.borneoDeviceApi.setFactoryNvsU8(
        boundDevice!.device,
        overtempEnabled.namespace,
        overtempEnabled.key,
        overtempEnabled.value ? 1 : 0,
      );
      overtempEnabled.reset();
    }

    if (overtempCutoff.changed) {
      await this.borneoDeviceApi.setFactoryNvsU8(
        boundDevice!.device,
        overtempCutoff.namespace,
        overtempCutoff.key,
        overtempCutoff.value,
      );
      overtempCutoff.reset();
    }

    if (channelCountSetting.changed) {
      await this.borneoDeviceApi.setFactoryNvsU8(
        boundDevice!.device,
        channelCountSetting.namespace,
        channelCountSetting.key,
        channelCountSetting.value,
      );
      channelCountSetting.reset();
    }

    // Channel metadata updates (name/color)
    for (final channel in _channels) {
      if (channel.nameChanged) {
        await this.borneoDeviceApi.setFactoryNvsString(
          boundDevice!.device,
          "led",
          "ch${channel.index}.name",
          channel.name,
        );
      }
      if (channel.colorChanged) {
        await this.borneoDeviceApi.setFactoryNvsString(
          boundDevice!.device,
          "led",
          "ch${channel.index}.color",
          channel.color,
        );
      }
      if (channel.changed) {
        channel.syncInitial();
      }
    }

    await this.borneoDeviceApi.reboot(boundDevice!.device);
  }
}
