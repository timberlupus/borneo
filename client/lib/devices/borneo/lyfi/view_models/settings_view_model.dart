import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/core/infrastructure/timezone.dart';
import 'package:borneo_common/exceptions.dart' as bo_ex;
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
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

  bool _cloudEnabled = false;
  bool get cloudEnabled => _cloudEnabled;
  bool get canUpdateCloudEnabled => !isBusy && isOnline;

  FanMode _fanMode = FanMode.manual;
  FanMode get fanMode => _fanMode;
  bool get canUpdateFanMode => !isBusy && isOnline;

  int _manualFanPower = 0;
  int get manualFanPower => _manualFanPower;
  bool get canUpdateManualFanPower => !isBusy && isOnline && _fanMode == FanMode.manual;

  PowerBehavior _powerBehavior;
  PowerBehavior get powerBehavior => _powerBehavior;
  bool get canUpdatePowerBehavior => !isBusy && isOnline;
  bool get isControllerSettingsAvailable => borneoInfo.productMode == ProductMode.standalone;

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
    _cloudEnabled = await api.getCloudEnabled(boundDevice!.device);
    _fanMode = await api.getFanMode(boundDevice!.device);
    _manualFanPower = await api.getFanManualPower(boundDevice!.device);
  }

  Future<void> updateGeoLocation(LatLng location, {CancellationToken? cancel}) async {
    try {
      final loc = GeoLocation(lat: location.latitude, lng: location.longitude);
      await super.lyfiDeviceApi.setLocation(super.boundDevice!.device, loc, cancelToken: cancel);
      _location = loc;
      notification.showSuccess(_gt.translate("Location updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update device location: $e"));
    }
  }

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

  Future<void> updateTimezone({CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      final tzc = TimezoneConverter();
      await tzc.init();
      final posixTZ = await tzc.getLocalPosixTimezone();
      await api.setTimeZone(boundDevice!.device, posixTZ!, cancelToken: cancel);
      _timezone = posixTZ;
      notification.showSuccess(_gt.translate("Time zone updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update device time zone: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateLedCorrectionMethod(LedCorrectionMethod newMethod, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await api.setCorrectionMethod(boundDevice!.device, newMethod, cancelToken: cancel);
      _correctionMethod = newMethod;
      notification.showSuccess(_gt.translate("LED correction method updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update LED correction method: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateTemporaryDuration(Duration dur, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await api.setTemporaryDuration(boundDevice!.device, dur, cancelToken: cancel);
      _temporaryDuration = dur;
      notification.showSuccess(_gt.translate("Temporary duration updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update temporary duration: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateCloudEnabled(bool enabled, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await api.setCloudEnabled(boundDevice!.device, enabled, cancelToken: cancel);
      _cloudEnabled = enabled;
      notification.showSuccess(_gt.translate("Cloud simulation mode updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update cloud simulation mode: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateFanMode(FanMode mode, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await api.setFanMode(boundDevice!.device, mode, cancelToken: cancel);
      _fanMode = mode;
      globalEventBus.fire(LyfiFanModeChangedEvent(boundDevice!.device, fanMode: mode));
      notification.showSuccess(_gt.translate("Fan mode updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update fan mode: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateManualFanPower(int power, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await api.setFanManualPower(boundDevice!.device, power, cancelToken: cancel);
      _manualFanPower = power;
      notification.showSuccess(_gt.translate("Manual fan power updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update manual fan power: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updatePowerBehavior(PowerBehavior behavior, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await api.setPowerBehavior(boundDevice!.device, behavior, cancelToken: cancel);
      _powerBehavior = behavior;
      notification.showSuccess(_gt.translate("Power behavior updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update power behavior: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> updateName(String newName, {CancellationToken? cancel}) async {
    isBusy = true;
    notifyListeners();
    try {
      await borneoDeviceApi.setName(boundDevice!.device, newName, cancelToken: cancel);
      await deviceManager.update(deviceID, name: newName);
      notification.showSuccess(_gt.translate("Device name updated successfully"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to update device name: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> factoryReset() async {
    isBusy = true;
    notifyListeners();
    try {
      await api.factoryReset(boundDevice!.device);
      notification.showSuccess(_gt.translate("Device restored to factory settings"));
    } catch (e) {
      notification.showError(_gt.translate("Failed to restore device to factory settings: $e"));
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
