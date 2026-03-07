import 'dart:async';
import 'dart:collection';

import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:flutter/foundation.dart';

class NewDeviceCandidatesStore extends ChangeNotifier {
  final IDeviceManager _deviceManager;
  final Map<String, SupportedDeviceDescriptor> _candidatesByFingerprint = {};
  late final StreamSubscription<NewDeviceFoundEvent> _newDeviceFoundSub;
  late final StreamSubscription<NewDeviceEntityAddedEvent> _newDeviceAddedSub;
  bool _disposed = false;

  NewDeviceCandidatesStore(this._deviceManager) {
    _newDeviceFoundSub = _deviceManager.allDeviceEvents.on<NewDeviceFoundEvent>().listen(_onNewDeviceFound);
    _newDeviceAddedSub = _deviceManager.allDeviceEvents.on<NewDeviceEntityAddedEvent>().listen(_onNewDeviceAdded);
  }

  UnmodifiableListView<SupportedDeviceDescriptor> get candidates {
    return UnmodifiableListView(_candidatesByFingerprint.values);
  }

  int get count => _candidatesByFingerprint.length;

  SupportedDeviceDescriptor? byFingerprint(String fingerprint) {
    return _candidatesByFingerprint[fingerprint];
  }

  void _onNewDeviceFound(NewDeviceFoundEvent event) {
    final previous = _candidatesByFingerprint[event.device.fingerprint];
    if (_isSameCandidate(previous, event.device)) {
      return;
    }

    _candidatesByFingerprint[event.device.fingerprint] = event.device;
    _notifyIfActive();
  }

  void _onNewDeviceAdded(NewDeviceEntityAddedEvent event) {
    if (_candidatesByFingerprint.remove(event.device.fingerprint) != null) {
      _notifyIfActive();
    }
  }

  bool _isSameCandidate(SupportedDeviceDescriptor? left, SupportedDeviceDescriptor right) {
    if (left == null) {
      return false;
    }

    return left.fingerprint == right.fingerprint &&
        left.address == right.address &&
        left.name == right.name &&
        left.driverDescriptor.id == right.driverDescriptor.id;
  }

  void _notifyIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      _newDeviceFoundSub.cancel();
      _newDeviceAddedSub.cancel();
    }
    super.dispose();
  }
}
