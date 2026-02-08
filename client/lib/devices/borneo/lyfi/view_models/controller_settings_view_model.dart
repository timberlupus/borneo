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

class ControllerSettingsViewModel extends BaseLyfiDeviceViewModel {
  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();

  late final NvsSettingEntry<int> pwmFreq;
  late final NvsSettingEntry<bool> overpowerEnabled;
  late final NvsSettingEntry<int> overpowerCutoff;
  late final NvsSettingEntry<bool> overtempEnabled;
  late final NvsSettingEntry<int> overtempCutoff;
  late final NvsSettingEntry<int> channelCountSetting;

  late final int channelCount;
  late final List<String> _channelNames;
  late final List<String> _initialChannelNames;
  late final List<String> _channelColors;
  late final List<String> _initialChannelColors;
  late final List<bool> _channelNameValid;

  bool get hasChanges {
    final basicChanged =
        pwmFreq.changed ||
        overpowerEnabled.changed ||
        overpowerCutoff.changed ||
        overtempEnabled.changed ||
        overtempCutoff.changed ||
        channelCountSetting.changed;
    final channelChanged = List.generate(
      channelCount,
      (i) => _channelNames[i] != _initialChannelNames[i] || _channelColors[i] != _initialChannelColors[i],
    ).any((x) => x);
    return basicChanged || channelChanged;
  }

  bool get canSubmit => hasChanges && _channelNameValid.every((v) => v);

  String getChannelName(int index) => _channelNames[index];
  String getChannelColor(int index) => _channelColors[index];
  bool isChannelNameValid(int index) => _channelNameValid[index];
  void setChannelName(int index, String value) {
    if (_channelNames[index] != value) {
      _channelNames[index] = value;
      _channelNameValid[index] = _validateChannelName(value);
      notifyListeners();
    }
  }

  void setChannelColor(int index, String value) {
    if (_channelColors[index] != value) {
      _channelColors[index] = value;
      notifyListeners();
    }
  }

  ControllerSettingsViewModel({
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
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

    // Initialize channel metadata from device info
    final info = super.lyfiDeviceInfo;
    channelCountSetting = NvsSettingEntry<int>(info.channelCount, notifyListeners, namespace: "led", key: "chcount");

    channelCount = info.channelCountMax;
    _channelNames = List<String>.generate(
      channelCount,
      (i) => i < info.channelCount ? info.channels[i].name : '',
      growable: false,
    );
    _initialChannelNames = List<String>.from(_channelNames, growable: false);
    _channelColors = List<String>.generate(
      channelCount,
      (i) => i < info.channelCount ? info.channels[i].color : '#FFFFFF',
      growable: false,
    );
    _initialChannelColors = List<String>.from(_channelColors, growable: false);
    _channelNameValid = List<bool>.generate(
      channelCount,
      (i) => _validateChannelName(_channelNames[i]),
      growable: false,
    );

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
    for (int ch = 0; ch < channelCount; ch++) {
      final bool nameChanged = _channelNames[ch] != _initialChannelNames[ch];
      final bool colorChanged = _channelColors[ch] != _initialChannelColors[ch];
      if (nameChanged) {
        await this.borneoDeviceApi.setFactoryNvsString(boundDevice!.device, "led", "ch$ch.name", _channelNames[ch]);
      }
      if (colorChanged) {
        await this.borneoDeviceApi.setFactoryNvsString(boundDevice!.device, "led", "ch$ch.color", _channelColors[ch]);
      }
      _initialChannelNames[ch] = _channelNames[ch];
      _initialChannelColors[ch] = _channelColors[ch];
    }

    await this.borneoDeviceApi.reboot(boundDevice!.device);
  }
}
