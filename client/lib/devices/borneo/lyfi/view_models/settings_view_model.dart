import 'dart:io';

import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/infrastructure/timezone.dart';
import 'package:borneo_app/view_models/devices/base_device_view_model.dart';
import 'package:borneo_common/exceptions.dart' as boEX;
import 'package:borneo_common/io/net/rssi.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';

import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';

class SettingsViewModel extends BaseLyfiDeviceViewModel {
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;
  final bool isOnline = true; // FIXME

  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();
  BoundDevice get boundDevice => deviceManager.getBoundDevice(deviceID);

  GeoLocation? _location;
  GeoLocation? get location => _location;
  bool get canUpdateGeoLocation => !isBusy && isOnline;

  String? _timezone;
  String? get timezone => _timezone;
  bool get canUpdateTimezone => !isBusy && isOnline;

  LedCorrectionMethod _correctionMethod = LedCorrectionMethod.log;
  LedCorrectionMethod get correctionMethod => _correctionMethod;
  bool get canUpdateCorrectionMethod => !isBusy && isOnline;

  PowerBehavior _powerBehavior;
  PowerBehavior get powerBehavior => _powerBehavior;
  bool get canUpdatePowerBehavior => !isBusy && isOnline;

  SettingsViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required this.address,
    required this.borneoStatus,
    required this.borneoInfo,
    required this.ledInfo,
    required this.ledStatus,
    required GeoLocation? location,
    required PowerBehavior powerBehavior,
  }) : _location = location,
       _powerBehavior = powerBehavior,
       _timezone = borneoStatus.timezone;

  @override
  Future<void> onInitialize() async {
    _correctionMethod = await api.getCorrectionMethod(boundDevice.device);
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
      locationSettings: LocationSettings(accuracy: LocationAccuracy.lowest, timeLimit: Duration(seconds: 5)),
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

  Future<void> updatePowerBehavior(PowerBehavior behavior) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      await api.setPowerBehavior(boundDevice.device, behavior);
      _powerBehavior = behavior;
    });
  }
}
