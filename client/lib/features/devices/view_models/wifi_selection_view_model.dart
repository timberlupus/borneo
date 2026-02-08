import 'package:borneo_app/core/services/devices/ble_provisioner.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:logger/logger.dart';

class WifiSelectionViewModel extends AbstractScreenViewModel {
  final IBleProvisioner _bleProvisioner;
  final String deviceName;
  final Logger _logger = Logger(); // Or inject

  List<WifiNetwork>? _networks;
  List<WifiNetwork>? get networks => _networks;
  final CancellationToken _scanCancelToken = CancellationToken();

  WifiSelectionViewModel(
    this._bleProvisioner,
    this.deviceName, {
    required super.globalEventBus,
    required super.gt,
    super.logger,
  });

  @override
  Future<void> onInitialize() async {
    await scanNetworks();
  }

  Future<void> scanNetworks() async {
    isBusy = true;
    notifyListeners();
    try {
      // Assuming PoP is empty string as decided
      _networks = await _bleProvisioner.scanWifiNetworks(deviceName, cancelToken: _scanCancelToken);
    } on CancelledException {
      logger?.i('The scanning task has been cancelled.');
    } catch (e, stackTrace) {
      _logger.e('Failed to scan wifi networks', error: e, stackTrace: stackTrace);
      notifyAppError(e.toString());
    } finally {
      isBusy = false;
      if (!_scanCancelToken.isCancelled && !super.isDisposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (isBusy) {
      _scanCancelToken.cancel();
    }
    super.dispose();
  }
}
