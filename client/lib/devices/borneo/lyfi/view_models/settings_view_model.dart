import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/infrastructure/timezone.dart';
import 'package:borneo_common/exceptions.dart' as bo_ex;
import 'package:geolocator/geolocator.dart';

import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:latlong2/latlong.dart';

class SettingsViewModel extends BaseLyfiDeviceViewModel {
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;

  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();

  GeoLocation? _location;
  GeoLocation? get location => _location;
  bool get canUpdateGeoLocation => !isBusy && isOnline;

  String? _timezone;
  String? get timezone => _timezone;
  bool get canUpdateTimezone => !isBusy && isOnline;

  LedCorrectionMethod _correctionMethod = LedCorrectionMethod.log;
  LedCorrectionMethod get correctionMethod => _correctionMethod;
  bool get canUpdateCorrectionMethod => !isBusy && isOnline;

  Duration _temporaryDuration = Duration(minutes: 20);
  Duration get temporaryDuration => _temporaryDuration;
  bool get canUpdateTemporaryDuration => !isBusy && isOnline;

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
    _correctionMethod = await api.getCorrectionMethod(boundDevice!.device);
  }

  Future<void> updateGeoLocation(LatLng location) async {
    super.enqueueUIJob(() async {
      final loc = GeoLocation(lat: location.latitude, lng: location.longitude);
      await super.lyfiDeviceApi.setLocation(super.boundDevice!.device, loc);
      _location = loc;
    });
  }

  Future<Position> getLocation() async {
    // TODO cancellable
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw bo_ex.InvalidOperationException(message: 'Please enable location services');
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw bo_ex.PermissionDeniedException(message: 'Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw bo_ex.PermissionDeniedException(message: 'Location permissions are permanently denied');
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 30),
        distanceFilter: 100,
      ),
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
      await api.setTimeZone(boundDevice!.device, posixTZ!);
      _timezone = posixTZ;
    });
  }

  Future<void> updateLedCorrectionMethod(LedCorrectionMethod newMethod) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      await api.setCorrectionMethod(boundDevice!.device, newMethod);
      _correctionMethod = newMethod;
    });
  }

  Future<void> updateTemporaryDuration(Duration dur) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      await api.setTemporaryDuration(boundDevice!.device, dur);
      _temporaryDuration = dur;
    });
  }

  Future<void> updatePowerBehavior(PowerBehavior behavior) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      await api.setPowerBehavior(boundDevice!.device, behavior);
      _powerBehavior = behavior;
    });
  }
}
