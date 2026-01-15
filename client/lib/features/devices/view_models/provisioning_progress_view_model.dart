import 'dart:async';
import 'package:borneo_app/core/services/devices/ble_provisioner.dart';
import 'package:borneo_app/features/devices/models/ble_provision_state.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:logger/logger.dart';

class ProvisioningProgressViewModel extends AbstractScreenViewModel {
  final IBleProvisioner _bleProvisioner;
  final String deviceName;
  final String ssid;
  final String password;
  final Logger _logger = Logger();

  BleProvisioningState _state = BleProvisioningState.idle;
  BleProvisioningState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final CancellationToken _provisionCancelToken = CancellationToken();

  ProvisioningProgressViewModel(
    this._bleProvisioner,
    this.deviceName,
    this.ssid,
    this.password, {
    required super.globalEventBus,
  });

  @override
  void dispose() {
    if (isBusy) {
      _provisionCancelToken.cancel();
    }
    super.dispose();
  }

  @override
  Future<void> onInitialize() async {
    // No-op or we could move startProvisioning here
  }

  Future<void> startProvisioning() async {
    if (_state != BleProvisioningState.idle) {
      return;
    }

    isBusy = true;
    notifyListeners();
    try {
      // 1. Sending Credentials
      _updateState(BleProvisioningState.sendingCredentials);

      // This sends credentials and waits for ESP confirmation
      await _bleProvisioner.provisionWifi(deviceName, ssid, password, cancelToken: _provisionCancelToken);

      // 2. Connecting to Wifi (Assumed by plugin usually, or happens now)
      _updateState(BleProvisioningState.connectingToWifi);

      // Provisioning completed successfully
      _updateState(BleProvisioningState.success);
    } on CancelledException {
      _logger.i('The provisioning task has been cancelled.');
    } catch (e, stackTrace) {
      _logger.e('Provisioning failed', error: e, stackTrace: stackTrace);
      _errorMessage = e.toString();
      _updateState(BleProvisioningState.failed);
    } finally {
      isBusy = false;
      if (!_provisionCancelToken.isCancelled && !super.isDisposed) {
        notifyListeners();
      }
    }
  }

  void _updateState(BleProvisioningState newState) {
    _state = newState;
    notifyListeners();
  }
}
