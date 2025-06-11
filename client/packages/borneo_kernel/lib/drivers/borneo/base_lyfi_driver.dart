// dart format width=120

import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:borneo_kernel_abstractions/models/wot/device.dart';
import 'package:borneo_kernel_abstractions/models/wot/adapter.dart';
import 'package:borneo_kernel_abstractions/models/wot/property.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class BaseLyfiDriver extends IDriver {
  @override
  Future<WotAdapter> createWotAdapter(Device device, DeviceEventBus deviceEvents,
      {CancellationToken? cancelToken}) async {
    final borneoApi = this as IBorneoDeviceApi;
    final lyfiApi = this as ILyfiDeviceApi;
    final borneoDeviceInfo = borneoApi.getGeneralDeviceInfo(device);
    final lyfiDeviecInfo = lyfiApi.getLyfiInfo(device);

    final generalStatus = await borneoApi.getGeneralDeviceStatus(device);
    final lyfiStatus = await lyfiApi.getLyfiStatus(device);

    final wotDevice = WotDevice(id: device.id, title: borneoDeviceInfo.name, type: ["OnOffSwitch"]);

    wotDevice.addProperty(
      WotOnOffProperty(value: generalStatus.power, valueForwarder: (update) => borneoApi.setOnOff(device, update)),
    );
    wotDevice.addProperty(
      WotLyfiStateProperty(
          value: lyfiStatus.state.name,
          valueForwarder: (update) => lyfiApi.switchMode(device, LyfiMode.fromString(update))),
    );
    wotDevice.addProperty(
      WotLyfiModeProperty(
          value: lyfiStatus.mode.name,
          valueForwarder: (update) => lyfiApi.switchState(device, LyfiState.fromString(update))),
    );

    if (generalStatus.temperature != null) {
      wotDevice.addProperty(WotOptionalIntegerProperty(
          name: 'temperature', title: 'Temperature', value: generalStatus.temperature, unit: '℃', readOnly: true));
    }

    wotDevice.addProperty(WotBooleanProperty(
      name: 'isStandaloneController',
      title: 'Is Standalone Controller',
      value: lyfiDeviecInfo.isStandaloneController,
      readOnly: true,
    ));

    wotDevice.addProperty(WotOptionalNumberProperty(
      name: 'nominalPower',
      title: 'Nominal Power in Watts',
      value: lyfiDeviecInfo.nominalPower,
      readOnly: true,
    ));

    wotDevice.addProperty(WotIntegerProperty(
      name: 'channelCount',
      title: 'Channel Count',
      value: lyfiDeviecInfo.channelCount,
      readOnly: true,
    ));

    final adapter = WotAdapter(wotDevice, deviceEvents: deviceEvents);

    adapter.addDevicePropertyEventSubscription<DevicePowerOnOffChangedEvent>("on", (e) => e.onOff);

    adapter.addDevicePropertyEventSubscription<LyfiStateChangedEvent>("state", (e) => e.state.name);

    adapter.addDevicePropertyEventSubscription<LyfiModeChangedEvent>("mode", (e) => e.mode.name);

    return adapter;
  }
}
