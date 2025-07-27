import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/core/infrastructure/timezone.dart';
import 'package:borneo_common/exceptions.dart' as bo_ex;
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:geolocator/geolocator.dart';

import 'package:latlong2/latlong.dart';

class SettingsViewModel extends BaseLyfiDeviceViewModel {
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;
  final GettextLocalizations _gt;

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

  SettingsViewModel(
    this._gt, {
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
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
    await super.onInitialize();
    _correctionMethod = await api.getCorrectionMethod(boundDevice!.device);
    _temporaryDuration = await api.getTemporaryDuration(boundDevice!.device);
  }

  Future<void> updateGeoLocation(LatLng location) async {
    super.enqueueUIJob(() async {
      try {
        final loc = GeoLocation(lat: location.latitude, lng: location.longitude);
        await super.lyfiDeviceApi.setLocation(super.boundDevice!.device, loc);
        _location = loc;
        notification.showSuccess(_gt.translate("Location updated successfully"));
      } catch (e) {
        notification.showError(_gt.translate("Failed to update device location: $e"));
      }
    });
  }

  /*
  Duration _getTimeDifference(String timezone1, String timezone2) {
    final location1 = tz.getLocation(timezone1);
    final location2 = tz.getLocation(timezone2);
    final now = tz.TZDateTime.now(location1);
    final offset1 = now.timeZoneOffset;
    final offset2 = tz.TZDateTime.now(location2).timeZoneOffset;
    return offset1 - offset2;
  }
  */

  Future<Position> getLocation({CancellationToken? cancel}) async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled().asCancellable(cancel);
    if (!serviceEnabled) {
      throw bo_ex.InvalidOperationException(message: _gt.translate('Please enable location services'));
    }

    // Check permissions
    permission = await Geolocator.checkPermission().asCancellable(cancel);
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission().asCancellable(cancel);
      if (permission == LocationPermission.denied) {
        throw bo_ex.PermissionDeniedException(message: _gt.translate('Location permissions are denied'));
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw bo_ex.PermissionDeniedException(message: _gt.translate('Location permissions are permanently denied'));
    }

    // Get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 30),
          distanceFilter: 100,
        ),
      ).asCancellable(cancel);
      return position;
    } catch (e) {
      notification.showError(_gt.translate("Failed to get location: $e"));
      rethrow;
    }
  }

  Future<void> updateTimezone() async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      try {
        final tzc = TimezoneConverter();
        await tzc.init();
        final posixTZ = await tzc.getLocalPosixTimezone();
        await api.setTimeZone(boundDevice!.device, posixTZ!);
        _timezone = posixTZ;
        notification.showSuccess(_gt.translate("Time zone updated successfully"));
      } catch (e) {
        notification.showError(_gt.translate("Failed to update device time zone: $e"));
      }
    });
  }

  Future<void> updateLedCorrectionMethod(LedCorrectionMethod newMethod) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      try {
        await api.setCorrectionMethod(boundDevice!.device, newMethod);
        _correctionMethod = newMethod;
        notification.showSuccess(_gt.translate("LED correction method updated successfully"));
      } catch (e) {
        notification.showError(_gt.translate("Failed to update LED correction method: $e"));
      }
    });
  }

  Future<void> updateTemporaryDuration(Duration dur) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      try {
        await api.setTemporaryDuration(boundDevice!.device, dur);
        _temporaryDuration = dur;
        notification.showSuccess(_gt.translate("Temporary duration updated successfully"));
      } catch (e) {
        notification.showError(_gt.translate("Failed to update temporary duration: $e"));
      }
    });
  }

  Future<void> updatePowerBehavior(PowerBehavior behavior) async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      try {
        await api.setPowerBehavior(boundDevice!.device, behavior);
        _powerBehavior = behavior;
        notification.showSuccess(_gt.translate("Power behavior updated successfully"));
      } catch (e) {
        notification.showError(_gt.translate("Failed to update power behavior: $e"));
      }
    });
  }

  Future<void> factoryReset() async {
    super.enqueueUIJob(() async {
      isBusy = true;
      notifyListeners();
      try {
        await api.factoryReset(boundDevice!.device);
        notification.showSuccess(_gt.translate("Device restored to factory settings"));
      } catch (e) {
        notification.showError(_gt.translate("Failed to restore device to factory settings: $e"));
      }
    });
  }
}
