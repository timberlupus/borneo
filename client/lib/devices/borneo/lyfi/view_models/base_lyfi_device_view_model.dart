import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  LyfiDeviceStatus? _lyfiStatus;

  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;
  LyfiDeviceInfo get lyfiDeviceInfo => lyfiDeviceApi.getLyfiInfo(super.boundDevice!.device);

  LyfiDeviceStatus? get lyfiDeviceStatus => _lyfiStatus;

  double? get nominalPower => lyfiDeviceInfo.nominalPower;

  LyfiMode _mode = LyfiMode.manual;
  LyfiState _state = LyfiState.normal;

  @override
  Future<void> onInitialize() async {
    super.onInitialize();
    if (super.isOnline) {
      await super.refreshStatus();
    }
  }

  LyfiMode get mode => _mode;

  Future<void> setMode(LyfiMode newMode) async {
    if (newMode == _mode) {
      return;
    }
    try {
      await lyfiDeviceApi.switchMode(super.boundDevice!.device, newMode);
      _mode = newMode;
    } catch (_) {
      await refreshStatus();
      rethrow;
    }
  }

  LyfiState get state => _state;

  Future<void> setState(LyfiState newState) async {
    if (newState == _state) {
      return;
    }
    try {
      await lyfiDeviceApi.switchState(super.boundDevice!.device, newState);
      _state = newState;
    } catch (_) {
      await refreshStatus();
      rethrow;
    }
  }

  bool get isLocked => state.isLocked;

  BaseLyfiDeviceViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    super.logger,
  });

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    await super.refreshStatus(cancelToken: cancelToken);
    _lyfiStatus = await lyfiDeviceApi.getLyfiStatus(boundDevice!.device, cancelToken: cancelToken);
    _mode = _lyfiStatus?.mode ?? LyfiMode.manual;
    _state = _lyfiStatus?.state ?? LyfiState.normal;
  }
}
