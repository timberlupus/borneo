import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';

class SettingsViewModel extends BaseViewModel {
  final String deviceID;
  final DeviceManager deviceManager;
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;

  final GeoLocation? location;

  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();
  BoundDevice get boundDevice => deviceManager.getBoundDevice(deviceID);

  PowerBehavior _selectedPowerBehavior;
  PowerBehavior get selectedPowerBehavior => _selectedPowerBehavior;
  set selectedPowerBehavior(PowerBehavior value) {
    _selectedPowerBehavior = value;
    notifyListeners();
  }

  SettingsViewModel({
    required this.deviceManager,
    required this.deviceID,
    required this.address,
    required this.borneoStatus,
    required this.borneoInfo,
    required this.ledInfo,
    required this.ledStatus,
    required this.location,
    required PowerBehavior powerBehavior,
  }) : _selectedPowerBehavior = powerBehavior;

/*
  Future<Map<String, dynamic>?> _getLocationWithTimezone() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return {'error': 'Please enable location services'};
    }

    // Check permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return {'error': 'Location permissions are denied'};
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return {'error': 'Location permissions are permanently denied'};
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition();

    // Get timezone information
    final timeZoneName = await _getTimeZone(position.latitude, position.longitude);

    return {'latitude': position.latitude, 'longitude': position.longitude, 'timeZone': timeZoneName};
  }
  */
}
