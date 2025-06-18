// dart format width=120

import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:borneo_wot/wot.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class BaseLyfiDriver extends IDriver {
  @override
  Future<WotThing> createWotAdapter(
    Device device,
    DeviceEventBus deviceEvents, {
    CancellationToken? cancelToken,
  }) async {
    final borneoApi = this as IBorneoDeviceApi;
    final lyfiApi = this as ILyfiDeviceApi;
    final borneoDeviceInfo = borneoApi.getGeneralDeviceInfo(device);

    // Create LyfiThing instance following Mozilla WebThing pattern
    final lyfiThing = LyfiThing(
      device: device,
      deviceEvents: deviceEvents,
      borneoApi: borneoApi,
      lyfiApi: lyfiApi,
      title: borneoDeviceInfo.name,
    );

    // Initialize all properties, actions, and events
    await lyfiThing.initialize();

    return lyfiThing;
  }
}
