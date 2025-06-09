import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/base_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../easy_setup_view_model.dart';

String _formatDuration(Duration duration) {
  final buffer = StringBuffer();

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours < 10) {
    buffer.write('0');
  }
  buffer.write(hours);
  buffer.write(':');

  if (minutes < 10) {
    buffer.write('0');
  }
  buffer.write(minutes);

  return buffer.toString();
}

class ScheduleEntryViewModel extends ChangeNotifier {
  final Duration _instant;
  final List<int> _channels = [];

  Duration get instant => _instant;
  String get instantText => _formatDuration(_instant);
  List<int> get channels => _channels;

  ScheduleEntryViewModel(ScheduledInstant model) : _instant = model.instant {
    _channels.addAll(model.color);
  }

  ScheduledInstant toModel() => ScheduledInstant(instant: _instant, color: _channels);
}

class ScheduleEditorViewModel extends BaseEditorViewModel {
  static const Duration defaultInstantSpan = Duration(minutes: 30);
  static const int maxEntries = 48;

  final EasySetupViewModel easySetupViewModel;

  int? _currentEntryIndex;

  final List<ScheduleEntryViewModel> _entries = [];

  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  List<ScheduleEntryViewModel> get entries => _entries;
  Iterable<int> get instants => _entries.map((x) => x.instant.inSeconds);
  bool get isPreviewMode => parent.ledState == LedState.preview;

  @override
  bool get canEdit => parent.isOnline && parent.isOn && parent.mode == LedRunningMode.scheduled;

  bool get canChangeColor => canEdit && currentEntry != null;

  ScheduleEntryViewModel? get currentEntry => _currentEntryIndex != null ? _entries[_currentEntryIndex!] : null;

  ILyfiDeviceApi get _deviceApi => parent.boundDevice!.driver as ILyfiDeviceApi;

  ScheduleEditorViewModel(super.parent) : easySetupViewModel = EasySetupViewModel();

  @override
  Future<void> onInitialize() async {
    final deviceSideInstants = await super.deviceApi.getSchedule(parent.boundDevice!.device);

    _entries.addAll(deviceSideInstants.map((x) => ScheduleEntryViewModel(x)));

    if (deviceSideInstants.isNotEmpty) {
      var currentEntryIndex = deviceSideInstants.indexWhere((x) => !x.isZero);
      if (currentEntryIndex < 0) {
        currentEntryIndex = 0;
      }
      _setCurrentEntry(currentEntryIndex);
    }
  }

  void _setCurrentEntry(int? index) {
    if (index != null) {
      _currentEntryIndex = index;
      for (int channelIndex = 0; channelIndex < channels.length; channelIndex++) {
        channels[channelIndex].value = currentEntry!.channels[channelIndex];
      }
    } else {
      for (final ch in channels) {
        ch.value = 0;
      }
      _currentEntryIndex = null;
    }
  }

  Future<void> setCurrentEntryAndSyncDimmingColor(int index) async {
    _setCurrentEntry(index);
    await syncDimmingColor(false);
    notifyListeners();
  }

  bool get canPrevInstant =>
      isInitialized && !isPreviewMode && _entries.length > 1 && _currentEntryIndex != null && _currentEntryIndex! > 0;

  Future<void> prevInstant() async {
    if (_currentEntryIndex == null) {
      return;
    }

    if (_currentEntryIndex! > 0) {
      await setCurrentEntryAndSyncDimmingColor(_currentEntryIndex! - 1);
    }
  }

  bool get canNextInstant =>
      isInitialized &&
      !isPreviewMode &&
      _entries.length > 1 &&
      _currentEntryIndex != null &&
      _currentEntryIndex! < _entries.length - 1;

  Future<void> nextInstant() async {
    if (_currentEntryIndex == null) {
      return;
    }

    if (_currentEntryIndex! < _entries.length - 1) {
      await setCurrentEntryAndSyncDimmingColor(_currentEntryIndex! + 1);
    }
  }

  bool get canRemoveCurrentInstant => isInitialized && _entries.isNotEmpty && _currentEntryIndex != null;

  void removeCurrentInstant() {
    if (_currentEntryIndex == null) {
      return;
    }

    int removed = _currentEntryIndex!;
    _entries.removeAt(_currentEntryIndex!);
    isChanged = true;

    if (_entries.isNotEmpty) {
      if (removed >= 1) {
        setCurrentEntryAndSyncDimmingColor(removed - 1);
      } else {
        setCurrentEntryAndSyncDimmingColor(0);
      }
    } else {
      _setCurrentEntry(null);
      notifyListeners();
    }
  }

  bool get canClearInstants => isInitialized && _entries.isNotEmpty;

  void clearEntries({bool notify = true}) {
    if (_entries.isEmpty) {
      return;
    }

    _setCurrentEntry(null);
    for (var x in _entries) {
      x.dispose();
    }
    _entries.clear();
    if (notify) {
      notifyListeners();
    }
  }

  bool get canAddInstant => isInitialized && _entries.length < maxEntries;

  Future<void> addInstant(Duration instant) async {
    if (_entries.length >= maxEntries) return;
    int insertPos = _findInstantInsertPosition(instant);
    if (_currentEntryIndex != null) {
      _insertInstant(insertPos, instant, _entries[_currentEntryIndex!].channels);
    } else {
      _insertInstant(insertPos, instant, List<int>.filled(deviceInfo.channelCount, 0, growable: false));
    }
    await setCurrentEntryAndSyncDimmingColor(insertPos);
  }

  int _findInstantInsertPosition(Duration instant) {
    int insertPos = 0;
    for (insertPos = 0; insertPos < entries.length; insertPos++) {
      if (entries[insertPos].instant > instant) {
        break;
      }
    }
    return insertPos;
  }

  ScheduleEntryViewModel _insertInstant(int insertPos, Duration instant, List<int> channels) {
    final entry = ScheduleEntryViewModel(ScheduledInstant(instant: instant, color: channels));
    _entries.insert(insertPos, entry);
    isChanged = true;
    return entry;
  }

  ScheduleEntryViewModel _appendInstant(Duration instant, List<int> channels) {
    final entry = ScheduleEntryViewModel(ScheduledInstant(instant: instant, color: channels));

    _entries.add(entry);
    isChanged = true;
    return entry;
  }

  @override
  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < channels.length && value != channels[index].value) {
      channels[index].value = value;
      currentEntry?.channels[index] = value;
      await super.syncDimmingColor(true);
      isChanged = true;
      notifyListeners();
    }
  }

  void togglePreviewMode() {
    parent.enqueueJob(() async {
      if (isPreviewMode) {
        _deviceApi.switchState(parent.boundDevice!.device, LedState.dimming);
      } else {
        _deviceApi.switchState(parent.boundDevice!.device, LedState.preview);
      }
      notifyListeners();
    });
  }

  @override
  Future<void> save() async {
    final schedule = _entries.map((x) => x.toModel());
    await _deviceApi.setSchedule(parent.boundDevice!.device, schedule);
  }

  void resetChannelValues() {}

  Future<void> loadCurve(Iterable<ScheduledInstant> instants) async {
    clearEntries(notify: false);
    for (final i in instants) {
      _appendInstant(i.instant, i.color);
    }
    if (instants.length > 1) {
      await setCurrentEntryAndSyncDimmingColor(1);
    } else if (instants.isNotEmpty) {
      await setCurrentEntryAndSyncDimmingColor(0);
    }
  }

  Future<void> easySetupEnter() async {
    clearEntries(notify: false);
  }

  Future<void> easySetupFinish() async {
    final easyInstants = easySetupViewModel.build(this);
    if (channels.any((x) => x.value > 0)) {
      await loadCurve(easyInstants);
    }
  }
}
