import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:synchronized/synchronized.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  final _lock = Lock();
  LyfiDeviceStatus? _lyfiStatus;

  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;
  LyfiDeviceInfo get lyfiDeviceInfo => lyfiDeviceApi.getLyfiInfo(super.boundDevice!.device);
  LyfiDeviceStatus get lyfiDeviceStatus => _lyfiStatus!;

  BaseLyfiDeviceViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    super.logger,
  });

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    await super.refreshStatus(cancelToken: cancelToken);
    await _lock.synchronized(() async {
      _lyfiStatus = await lyfiDeviceApi.getLyfiStatus(boundDevice!.device); // TODO cancel
    });
  }
}
