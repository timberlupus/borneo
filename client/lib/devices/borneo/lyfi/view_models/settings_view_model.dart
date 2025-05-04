import 'dart:io';

import 'package:borneo_app/infrastructure/timezone.dart';
import 'package:borneo_app/view_models/devices/base_device_view_model.dart';
import 'package:borneo_common/exceptions.dart' as boEX;
import 'package:borneo_common/io/net/rssi.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';

import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';

class SettingsViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final String deviceID;
  final DeviceManager deviceManager;
  final EventBus globalEventBus;
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;
  final bool isOnline = true; // FIXME

  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();
  BoundDevice get boundDevice => deviceManager.getBoundDevice(deviceID);

  PowerBehavior _selectedPowerBehavior;
  PowerBehavior get selectedPowerBehavior => _selectedPowerBehavior;
  set selectedPowerBehavior(PowerBehavior value) {
    _selectedPowerBehavior = value;
    notifyListeners();
  }

  GeoLocation? _location;
  GeoLocation? get location => _location;
  bool get canUpdateGeoLocation => !isBusy && isOnline;

  String? _timezone;
  String? get timezone => _timezone;
  bool get canUpdateTimezone => !isBusy && isOnline;

  LedCorrectionMethod _correctionMethod = LedCorrectionMethod.log;
  LedCorrectionMethod get correctionMethod => _correctionMethod;
  bool get canUpdateCorrectionMethod => !isBusy && isOnline;

  SettingsViewModel({
    required this.deviceID,
    required this.deviceManager,
    required this.globalEventBus,
    required this.address,
    required this.borneoStatus,
    required this.borneoInfo,
    required this.ledInfo,
    required this.ledStatus,
    required GeoLocation? location,
    required PowerBehavior powerBehavior,
  }) : _selectedPowerBehavior = powerBehavior,
       _location = location,
       _timezone = borneoStatus.timezone;

  Future<void> initialize() async {
    isBusy = true;
    try {
      _correctionMethod = await api.getCorrectionMethod(boundDevice.device);
    } finally {
      isBusy = false;
    }
  }

  Future<void> updateGeoLocation() async {
    super.enqueueUIJob(() async {
      notifyListeners();
      final pos = await getLocation();
      final loc = GeoLocation(lat: pos.latitude, lng: pos.longitude);
      await api.setLocation(boundDevice.device, loc);
      _location = loc;
    });
  }

  Future<Position> getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw boEX.InvalidOperationException(message: 'Please enable location services');
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw boEX.PermissionDeniedException(message: 'Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw boEX.PermissionDeniedException(message: 'Location permissions are permanently denied');
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.lowest, timeLimit: Duration(milliseconds: 200)),
    );

    return position;
  }

  Future<void> updateTimezone() async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      final tzc = TimezoneConverter();
      await tzc.init();
      final posixTZ = await tzc.getLocalPosixTimezone();
      await api.setTimeZone(boundDevice.device, posixTZ!);
      _timezone = posixTZ;
    });
  }

  Future<void> updateLedCorrectionMethod(LedCorrectionMethod newMethod) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      await api.setCorrectionMethod(boundDevice.device, newMethod);
      _correctionMethod = newMethod;
    });
  }
}
