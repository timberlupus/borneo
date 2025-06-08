import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:borneo_kernel_abstractions/models/wot/device.dart';
import 'package:borneo_kernel_abstractions/models/wot/adapter.dart';
import 'package:borneo_kernel_abstractions/models/wot/property.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class BaseLyfiDriver extends IDriver {
  @override
  Future<WotAdapter> createWotAdapter(
      Device device, DeviceEventBus deviceEvents,
      {CancellationToken? cancelToken}) async {
    final borneoApi = this as IBorneoDeviceApi;
    final borneoDeviceInfo = borneoApi.getGeneralDeviceInfo(device);

    final generalStatus = await borneoApi.getGeneralDeviceStatus(device);

    final wotDevice = WotDevice(
        id: device.id, title: borneoDeviceInfo.name, type: ["OnOffSwitch"]);

    wotDevice.addProperty(WotProperty<bool>(
        name: 'on',
        title: 'Power',
        type: 'boolean',
        value: generalStatus.power));

    if (generalStatus.temperature != null) {
      wotDevice.addProperty(WotProperty(
          name: 'temperature',
          title: 'Temperature',
          type: 'integer',
          value: generalStatus.temperature));
    }

    final adapter = WotAdapter(wotDevice, deviceEvents: deviceEvents);

    adapter.addPropertyEventSubscription<DevicePowerOnOffChangedEvent>(
        "on", (e) => e.onOff);

    return adapter;
  }
}
