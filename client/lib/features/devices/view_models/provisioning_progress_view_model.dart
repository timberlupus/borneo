import 'dart:async';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/features/devices/models/ble_provision_state.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:logger/logger.dart';

class ProvisioningProgressViewModel extends AbstractScreenViewModel {
  final IDeviceManager _deviceManager;
  final String deviceName;
  final String ssid;
  final String password;
  final Logger _logger = Logger();

  BleProvisioningState _state = BleProvisioningState.idle;
  BleProvisioningState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StreamSubscription? _deviceFoundSub;

  ProvisioningProgressViewModel(
    this._deviceManager,
    this.deviceName,
    this.ssid,
    this.password, {
    required super.globalEventBus,
  });

  @override
  void dispose() {
    _deviceFoundSub?.cancel();
    super.dispose();
  }

  @override
  Future<void> onInitialize() async {
    // No-op or we could move startProvisioning here
  }

  Future<void> startProvisioning() async {
    if (_state != BleProvisioningState.idle) return;

    try {
      // 1. Sending Credentials
      _updateState(BleProvisioningState.sendingCredentials);

      // This sends credentials and waits for ESP confirmation
      await _deviceManager.bleProvisioner.provisionWifi(deviceName, ssid, password);

      // 2. Connecting to Wifi (Assumed by plugin usually, or happens now)
      _updateState(BleProvisioningState.connectingToWifi);

      // 3. Checking Status (Waiting for mDNS functionality)
      // _updateState(BleProvisioningState.checkingStatus);

      // Listen for the device on mDNS
      // We expect the device to appear soon.
      // We need to match it. Assuming deviceName matches or slightly differs?
      // For now, we wait for ANY new device that matches name roughly.

      final completer = Completer<SupportedDeviceDescriptor>();

      void checkForMatch(SupportedDeviceDescriptor d) {
        // Log potential matches for debugging
        _logger.i('Comparing discovered device ${d.name} with provisioned target $deviceName');
        // Loose matching: ignore case, check containment
        if (!completer.isCompleted &&
            (d.name.toLowerCase().contains(deviceName.toLowerCase()) ||
                deviceName.toLowerCase().contains(d.name.toLowerCase()))) {
          completer.complete(d);
        }
      }

      _deviceFoundSub = _deviceManager.allDeviceEvents.on<NewDeviceFoundEvent>().listen((event) {
        checkForMatch(event.device);
      });
      // Also listen to unprovisioned mDNS which might come as well? Wait, NewDeviceFoundEvent is for unprovisioned/unbound.

      // Start discovery if not running (it should be running from previous screen, but ensure it)
      if (!_deviceManager.isDiscoverying) {
        await _deviceManager.startDiscovery();
      }

      // Timeout 60 seconds for mDNS
      final deviceTimestamp = await completer.future.timeout(
        Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Device did not appear on network after provisioning');
        },
      );

      // 4. Registering Device
      _updateState(BleProvisioningState.registeringDevice);
      await _deviceManager.addNewDevice(deviceTimestamp);

      _updateState(BleProvisioningState.success);
    } catch (e, stackTrace) {
      _logger.e('Provisioning failed', error: e, stackTrace: stackTrace);
      _errorMessage = e.toString();
      _updateState(BleProvisioningState.failed);
    }
  }

  void _updateState(BleProvisioningState newState) {
    _state = newState;
    notifyListeners();
  }
}
