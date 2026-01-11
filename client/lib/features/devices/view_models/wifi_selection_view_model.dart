import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:logger/logger.dart';

class WifiSelectionViewModel extends AbstractScreenViewModel {
  final IDeviceManager _deviceManager;
  final String deviceName;
  final Logger _logger = Logger(); // Or inject

  List<WifiNetwork>? _networks;
  List<WifiNetwork>? get networks => _networks;

  WifiSelectionViewModel(this._deviceManager, this.deviceName, {required super.globalEventBus});

  @override
  Future<void> onInitialize({CancellationToken? cancelToken}) async {
    await scanNetworks(cancelToken: cancelToken);
  }

  Future<void> scanNetworks({CancellationToken? cancelToken}) async {
    isBusy = true;
    notifyListeners();
    try {
      // Assuming PoP is empty string as decided
      _networks = await _deviceManager.bleProvisioner.scanWifiNetworks(deviceName, cancelToken: cancelToken);
    } catch (e, stackTrace) {
      _logger.e('Failed to scan wifi networks', error: e, stackTrace: stackTrace);
      notifyAppError(e.toString());
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
