import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/devices/ble_provisioner.dart';
import 'package:borneo_app/features/devices/models/ble_provision_state.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

enum ProvisioningWizardStep { selectWifi, enterPassword, provisioning, done }

class ProvisioningWizardViewModel extends AbstractScreenViewModel {
  final IBleProvisioner _bleProvisioner;
  final String deviceName;
  final IAppNotificationService? notificationService;

  ProvisioningWizardStep _step = ProvisioningWizardStep.selectWifi;
  ProvisioningWizardStep get step => _step;

  List<WifiNetwork>? _networks;
  List<WifiNetwork>? get networks => _networks;

  String? _selectedSsid;
  String? get selectedSsid => _selectedSsid;

  BleProvisioningState _provisioningState = BleProvisioningState.idle;
  BleProvisioningState get provisioningState => _provisioningState;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Whether provisioning succeeded (for the caller to know to refresh)
  bool _provisioningSucceeded = false;
  bool get provisioningSucceeded => _provisioningSucceeded;

  CancellationToken _cancelToken = CancellationToken();

  ProvisioningWizardViewModel(
    this._bleProvisioner,
    this.deviceName, {
    required super.globalEventBus,
    required super.gt,
    super.logger,
    this.notificationService,
  });

  @override
  Future<void> onInitialize() async {
    await scanNetworks();
  }

  Future<void> scanNetworks() async {
    isBusy = true;
    notifyListeners();
    try {
      _networks = await _bleProvisioner.scanWifiNetworks(deviceName, cancelToken: _cancelToken);
    } on CancelledException {
      notificationService?.showWarning(gt.translate('The WiFi scanning has been cancelled.'));
    } catch (e, stackTrace) {
      logger?.e('Failed to scan wifi networks', error: e, stackTrace: stackTrace);
      notifyAppError(e.toString());
    } finally {
      isBusy = false;
      if (!_cancelToken.isCancelled && !isDisposed) {
        notifyListeners();
      }
    }
  }

  void selectNetwork(String ssid) {
    _selectedSsid = ssid;
    _step = ProvisioningWizardStep.enterPassword;
    notifyListeners();
  }

  void backToWifiSelection() {
    _step = ProvisioningWizardStep.selectWifi;
    _selectedSsid = null;
    notifyListeners();
  }

  Future<void> startProvisioning(String password) async {
    _provisioningState = BleProvisioningState.idle;
    _errorMessage = null;
    _provisioningSucceeded = false;
    _step = ProvisioningWizardStep.provisioning;
    notifyListeners();

    isBusy = true;

    try {
      _updateProvisioningState(BleProvisioningState.sendingCredentials);
      await _bleProvisioner.provisionWifi(deviceName, _selectedSsid!, password, cancelToken: _cancelToken);
      _updateProvisioningState(BleProvisioningState.connectingToWifi);
      _updateProvisioningState(BleProvisioningState.success);
      _provisioningSucceeded = true;
      _step = ProvisioningWizardStep.done;
    } on CancelledException {
      logger?.i('Provisioning cancelled.');
    } catch (e, stackTrace) {
      logger?.e('Provisioning failed', error: e, stackTrace: stackTrace);
      _errorMessage = e.toString();
      _updateProvisioningState(BleProvisioningState.failed);
      _step = ProvisioningWizardStep.done;
    } finally {
      isBusy = false;
      if (!_cancelToken.isCancelled && !isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Retry from the beginning: back to WiFi scan.
  void retry() {
    _step = ProvisioningWizardStep.selectWifi;
    _selectedSsid = null;
    _provisioningState = BleProvisioningState.idle;
    _errorMessage = null;
    _provisioningSucceeded = false;
    // Create a fresh cancel token so the new scan/provision is not pre-cancelled.
    _cancelToken = CancellationToken();
    notifyListeners();
    scanNetworks();
  }

  void _updateProvisioningState(BleProvisioningState state) {
    _provisioningState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    if (isBusy) {
      _cancelToken.cancel();
    }
    super.dispose();
  }
}
