// dart format width=120

import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
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
    final lyfiDeviecInfo = lyfiApi.getLyfiInfo(device);

    final generalStatus = await borneoApi.getGeneralDeviceStatus(device);
    final lyfiStatus = await lyfiApi.getLyfiStatus(device);

    // Create WotThing directly instead of WotDevice + WotAdapter
    final wotThing = WotThing(
      id: device.id,
      title: borneoDeviceInfo.name,
      type: ["OnOffSwitch"],
      description: "Lyfi device",
    );

    // Add properties using the new WotProperty + WotValue pattern
    final onOffProperty = WotProperty<bool>(
      thing: wotThing,
      name: 'on',
      value: WotValue<bool>(
        initialValue: generalStatus.power,
        valueForwarder: (update) => borneoApi.setOnOff(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'On/Off',
        description: 'Power on/off state',
        readOnly: false,
      ),
    );
    wotThing.addProperty(onOffProperty);

    final stateProperty = WotProperty<String>(
      thing: wotThing,
      name: 'state',
      value: WotValue<String>(
        initialValue: lyfiStatus.state.name,
        valueForwarder: (update) => lyfiApi.switchState(device, LyfiState.fromString(update)),
      ),
      metadata: WotPropertyMetadata(type: 'string', title: 'State', description: 'Lyfi state', readOnly: false),
    );
    wotThing.addProperty(stateProperty);

    final modeProperty = WotProperty<String>(
      thing: wotThing,
      name: 'mode',
      value: WotValue<String>(
        initialValue: lyfiStatus.mode.name,
        valueForwarder: (update) => lyfiApi.switchMode(device, LyfiMode.fromString(update)),
      ),
      metadata: WotPropertyMetadata(type: 'string', title: 'Mode', description: 'Lyfi mode', readOnly: false),
    );
    wotThing.addProperty(modeProperty);

    if (generalStatus.temperature != null) {
      final temperatureProperty = WotProperty<int>(
        thing: wotThing,
        name: 'temperature',
        value: WotValue<int>(initialValue: generalStatus.temperature!),
        metadata: WotPropertyMetadata(
          type: 'integer',
          title: 'Temperature',
          description: 'Current temperature',
          unit: '℃',
          readOnly: true,
        ),
      );
      wotThing.addProperty(temperatureProperty);
    }

    final isStandaloneProperty = WotProperty<bool>(
      thing: wotThing,
      name: 'isStandaloneController',
      value: WotValue<bool>(initialValue: lyfiDeviecInfo.isStandaloneController),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Is Standalone Controller',
        description: 'Whether device is a standalone controller',
        readOnly: true,
      ),
    );
    wotThing.addProperty(isStandaloneProperty);

    if (lyfiDeviecInfo.nominalPower != null) {
      final nominalPowerProperty = WotProperty<double>(
        thing: wotThing,
        name: 'nominalPower',
        value: WotValue<double>(initialValue: lyfiDeviecInfo.nominalPower!),
        metadata: WotPropertyMetadata(
          type: 'number',
          title: 'Nominal Power in Watts',
          description: 'Nominal power consumption',
          readOnly: true,
        ),
      );
      wotThing.addProperty(nominalPowerProperty);
    }
    final channelCountProperty = WotProperty<int>(
      thing: wotThing,
      name: 'channelCount',
      value: WotValue<int>(initialValue: lyfiDeviecInfo.channelCount),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Channel Count',
        description: 'Number of channels',
        readOnly: true,
      ),
    );
    wotThing.addProperty(channelCountProperty);

    // Add color property for manual mode
    final colorProperty = WotProperty<List<int>>(
      thing: wotThing,
      name: 'color',
      value: WotValue<List<int>>(
        initialValue: await lyfiApi.getColor(device),
        valueForwarder: (update) => lyfiApi.setColor(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Color',
        description: 'LED channel brightness values',
        readOnly: false,
      ),
    );
    wotThing.addProperty(colorProperty);

    // Add temporary duration property
    final temporaryDuration = await lyfiApi.getTemporaryDuration(device);
    final temporaryDurationProperty = WotProperty<int>(
      thing: wotThing,
      name: 'temporaryDuration',
      value: WotValue<int>(
        initialValue: temporaryDuration.inMinutes,
        valueForwarder: (update) => lyfiApi.setTemporaryDuration(device, Duration(minutes: update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Temporary Duration',
        description: 'Duration for temporary mode in minutes',
        readOnly: false,
      ),
    );
    wotThing.addProperty(temporaryDurationProperty);

    // Add correction method property
    final correctionMethod = await lyfiApi.getCorrectionMethod(device);
    final correctionMethodProperty = WotProperty<String>(
      thing: wotThing,
      name: 'correctionMethod',
      value: WotValue<String>(
        initialValue: correctionMethod.name,
        valueForwarder: (update) => lyfiApi.setCorrectionMethod(device, LedCorrectionMethod.values.byName(update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Correction Method',
        description: 'LED correction method',
        readOnly: false,
      ),
    );
    wotThing.addProperty(correctionMethodProperty); // Add location property if available
    final location = await lyfiApi.getLocation(device);
    if (location != null) {
      final locationProperty = WotProperty<Map<String, double>>(
        thing: wotThing,
        name: 'location',
        value: WotValue<Map<String, double>>(
          initialValue: {'latitude': location.lat, 'longitude': location.lng},
          valueForwarder: (update) =>
              lyfiApi.setLocation(device, GeoLocation(lat: update['latitude']!, lng: update['longitude']!)),
        ),
        metadata: WotPropertyMetadata(
          type: 'object',
          title: 'Location',
          description: 'Geographic location',
          readOnly: false,
        ),
      );
      wotThing.addProperty(locationProperty);
    }

    // Add timezone enabled property
    final timeZoneEnabled = await lyfiApi.getTimeZoneEnabled(device);
    final timeZoneEnabledProperty = WotProperty<bool>(
      thing: wotThing,
      name: 'timeZoneEnabled',
      value: WotValue<bool>(
        initialValue: timeZoneEnabled,
        valueForwarder: (update) => lyfiApi.setTimeZoneEnabled(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Time Zone Enabled',
        description: 'Whether timezone adjustment is enabled',
        readOnly: false,
      ),
    );
    wotThing.addProperty(timeZoneEnabledProperty);

    // Add timezone offset property
    final timeZoneOffset = await lyfiApi.getTimeZoneOffset(device);
    final timeZoneOffsetProperty = WotProperty<int>(
      thing: wotThing,
      name: 'timeZoneOffset',
      value: WotValue<int>(
        initialValue: timeZoneOffset,
        valueForwarder: (update) => lyfiApi.setTimeZoneOffset(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Time Zone Offset',
        description: 'Timezone offset in seconds',
        readOnly: false,
      ),
    );
    wotThing.addProperty(timeZoneOffsetProperty);

    // Set up event subscriptions to update properties when device events occur
    // TODO: Set up event subscriptions similar to the old adapter pattern
    // This might need to be implemented differently with WotThing

    return wotThing;
  }
}
