// dart format width=120

import 'dart:async';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:logger/logger.dart';
import 'package:lw_wot/wot.dart';

import 'wot_properties.dart';

/// LyfiThing extends WotThing following Mozilla WebThing initialization pattern
/// This class uses default values during construction and binds to actual hardware asynchronously
class LyfiThing extends WotThing {
  final Logger? logger;
  final Device device;
  final DeviceEventBus deviceEvents;
  final IBorneoDeviceApi borneoApi;
  final ILyfiDeviceApi lyfiApi;

  // Property references
  late final ObservableWotProperty<bool, DevicePowerOnOffChangedEvent> onOffProperty;
  late final ObservableWotProperty<String, LyfiStateChangedEvent> stateProperty;
  late final ObservableWotProperty<String, LyfiModeChangedEvent> modeProperty;
  late final WotProperty<List<int>> colorProperty;
  late final ObservableWotProperty<ScheduleTable, LyfiScheduleChangedEvent> scheduleProperty;
  late final ObservableWotProperty<AcclimationSettings, LyfiAcclimationChangedEvent> acclimationProperty;
  late final ObservableWotProperty<GeoLocation?, LyfiLocationChangedEvent> locationProperty;
  late final ObservableWotProperty<String, LyfiCorrectionMethodChangedEvent> correctionMethodProperty;
  late final WotProperty<bool> timeZoneEnabledProperty;
  late final WotProperty<int> timeZoneOffsetProperty;
  late final WotProperty<int> keepTempProperty;
  late final WotProperty<int?> temperatureProperty;
  late final ObservableWotProperty<String, LyfiFanModeChangedEvent> fanModeProperty;
  late final ObservableWotProperty<int, Object> fanManualPowerProperty;

  LyfiThing({
    required this.device,
    required this.deviceEvents,
    required this.borneoApi,
    required this.lyfiApi,
    required super.title,
    this.logger,
  }) : super(id: device.id, type: ["OnOffSwitch", "Light"], description: "Lyfi LED lighting device");

  /// Mozilla WebThing style initialization - sync constructor with async hardware binding
  Future<void> initialize() async {
    // 1. Create properties with default/last known values first (like Mozilla WebThing)
    await _createPropertiesWithDefaults();

    // 2. Set up hardware binding asynchronously (like Mozilla WebThing ready callback)
    await _bindToHardware();

    // 3. Set up event listeners and periodic sync
    _setupPeriodicSync();
  }

  /// Create properties with reasonable defaults first, then bind to hardware
  /// This follows Mozilla WebThing pattern of creating Value objects with initial values
  Future<void> _createPropertiesWithDefaults() async {
    // Power property with default false, will be updated when hardware is ready
    onOffProperty = ObservableWotProperty<bool, DevicePowerOnOffChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'on',
      value: WotValue<bool>(
        initialValue: false, // Default value, updated in _bindToHardware
        valueForwarder: (update) => borneoApi.setOnOff(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'On/Off',
        description: 'Power on/off state',
        readOnly: false,
      ),
      eventName: 'powerChanged',
      mapper: (event) => event.onOff,
    );
    addProperty(onOffProperty);

    // State property with default state
    stateProperty = ObservableWotProperty<String, LyfiStateChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'state',
      value: WotValue<String>(
        initialValue: LyfiState.values.first.name, // Default state
        valueForwarder: (update) async {
          await lyfiApi.switchState(device, LyfiState.fromString(update));
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'State',
        description: 'Lyfi operating state',
        enumValues: LyfiState.values.map((e) => e.name).toList(),
        readOnly: false,
      ),
      eventName: 'stateChanged',
      mapper: (event) => event.state.name,
    );
    addProperty(stateProperty);

    // Mode property with default mode
    modeProperty = ObservableWotProperty<String, LyfiModeChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'mode',
      value: WotValue<String>(
        initialValue: LyfiMode.values.first.name, // Default mode
        valueForwarder: (update) => lyfiApi.switchMode(device, LyfiMode.fromString(update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Mode',
        description: 'Lyfi lighting mode',
        enumValues: LyfiMode.values.map((e) => e.name).toList(),
        readOnly: false,
      ),
      eventName: 'modeChanged',
      mapper: (event) => event.mode.name,
    );
    addProperty(modeProperty);

    // Color property with default all-off color
    colorProperty = WotProperty<List<int>>(
      thing: this,
      name: 'color',
      value: WotValue<List<int>>(
        initialValue: [0, 0, 0, 0], // Default 4-channel all off
        valueForwarder: (update) => lyfiApi.setColor(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Color',
        description: 'LED channel brightness values (0-100 per channel)',
        readOnly: false,
      ),
    );
    addProperty(colorProperty);

    // Schedule property
    scheduleProperty = ObservableWotProperty<ScheduleTable, LyfiScheduleChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'schedule',
      value: WotValue<ScheduleTable>(
        initialValue: [], // Default empty schedule
        valueForwarder: (update) => lyfiApi.setSchedule(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Schedule',
        description: 'LED lighting schedule with time instants and colors',
        readOnly: false,
      ),
      eventName: 'scheduleChanged',
      mapper: (event) => event.schedule,
    );
    addProperty(scheduleProperty);

    // Acclimation property
    acclimationProperty = ObservableWotProperty<AcclimationSettings, LyfiAcclimationChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'acclimation',
      value: WotValue<AcclimationSettings>(
        initialValue: AcclimationSettings(
          enabled: false,
          startTimestamp: DateTime.now().toUtc(),
          startPercent: 0,
          days: 0,
        ),
        valueForwarder: (update) => lyfiApi.setAcclimation(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'Acclimation',
        description: 'LED acclimation settings for gradual brightness increase',
        readOnly: false,
      ),
      eventName: 'acclimationChanged',
      mapper: (event) => event.settings,
    );
    addProperty(acclimationProperty);

    // Location property
    locationProperty = ObservableWotProperty<GeoLocation?, LyfiLocationChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'location',
      value: WotValue<GeoLocation?>(
        initialValue: null, // Default no location
        valueForwarder: (update) async {
          if (update != null) {
            await lyfiApi.setLocation(device, update);
          }
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'Location',
        description: 'Geographic location for sun simulation calculations',
        readOnly: false,
      ),
      eventName: 'locationChanged',
      mapper: (event) => event.location,
    );
    addProperty(locationProperty);

    // Correction method property
    correctionMethodProperty = ObservableWotProperty<String, LyfiCorrectionMethodChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'correctionMethod',
      value: WotValue<String>(
        initialValue: LedCorrectionMethod.log.name,
        valueForwarder: (update) =>
            lyfiApi.setCorrectionMethod(device, LedCorrectionMethodExtension.fromString(update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Correction Method',
        description: 'LED brightness correction method',
        enumValues: LedCorrectionMethod.values.map((e) => e.name).toList(),
        readOnly: false,
      ),
      eventName: 'correctionMethodChanged',
      mapper: (event) => event.method.name,
    );
    addProperty(correctionMethodProperty);

    // Timezone enabled property
    timeZoneEnabledProperty = WotProperty<bool>(
      thing: this,
      name: 'timeZoneEnabled',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) => lyfiApi.setTimeZoneEnabled(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Timezone Enabled',
        description: 'Whether timezone offset is enabled',
        readOnly: false,
      ),
    );
    addProperty(timeZoneEnabledProperty);

    // Timezone offset property
    timeZoneOffsetProperty = WotProperty<int>(
      thing: this,
      name: 'timeZoneOffset',
      value: WotValue<int>(
        initialValue: 0, // Default 0 offset
        valueForwarder: (update) => lyfiApi.setTimeZoneOffset(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Timezone Offset',
        description: 'Timezone offset in seconds from UTC',
        readOnly: false,
      ),
    );
    addProperty(timeZoneOffsetProperty);

    // Keep temperature property
    keepTempProperty = WotProperty<int>(
      thing: this,
      name: 'keepTemp',
      value: WotValue<int>(
        initialValue: 75, // Default 75°C
        valueForwarder: (update) async {
          // Note: This is read-only as it's a safety setting
          throw UnsupportedError('Keep temperature is read-only for safety');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Keep Temperature',
        description: 'Thermal protection temperature threshold in Celsius',
        readOnly: true,
      ),
    );
    addProperty(keepTempProperty);

    // Current temperature property
    temperatureProperty = WotProperty<int?>(
      thing: this,
      name: 'temperature',
      value: WotValue<int?>(
        initialValue: null, // Default null
        valueForwarder: (update) async {
          // Read-only property
          throw UnsupportedError('Temperature is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Current Temperature',
        description: 'Current device temperature in Celsius',
        readOnly: true,
      ),
    );
    addProperty(temperatureProperty);

    // Fan mode property
    fanModeProperty = ObservableWotProperty<String, LyfiFanModeChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'fanMode',
      value: WotValue<String>(
        initialValue: FanMode.pid.name, // Default PID mode
        valueForwarder: (update) => lyfiApi.setFanMode(device, FanMode.values.firstWhere((e) => e.name == update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Fan Mode',
        description: 'Fan control mode (PID adaptive or manual)',
        enumValues: FanMode.values.map((e) => e.name).toList(),
        readOnly: false,
      ),
      eventName: 'fanModeChanged',
      mapper: (event) => event.fanMode.name,
    );
    addProperty(fanModeProperty);

    // Fan manual power property
    fanManualPowerProperty = ObservableWotProperty<int, Object>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'fanManualPower',
      value: WotValue<int>(
        initialValue: 0, // Default 0% power
        valueForwarder: (update) => lyfiApi.setFanManualPower(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Fan Manual Power',
        description: 'Manual fan power level (0-100%)',
        minimum: 0,
        maximum: 100,
        readOnly: false,
      ),
      subscribe: false,
      eventName: '', // Not used
      mapper: (event) => 0, // Not used
    );
    addProperty(fanManualPowerProperty);
  }

  /// Bind properties to actual hardware state (like Mozilla WebThing ready callback)
  Future<void> _bindToHardware() async {
    try {
      // Get actual device state and update property values
      final generalStatus = await borneoApi.getGeneralDeviceStatus(device);
      final lyfiStatus = await lyfiApi.getLyfiStatus(device);
      final actualColor = await lyfiApi.getColor(device);
      final schedule = await lyfiApi.getSchedule(device);
      final acclimation = await lyfiApi.getAcclimation(device);
      final location = await lyfiApi.getLocation(device);
      final correctionMethod = await lyfiApi.getCorrectionMethod(device);
      final timeZoneEnabled = await lyfiApi.getTimeZoneEnabled(device);
      final timeZoneOffset = await lyfiApi.getTimeZoneOffset(device);
      final keepTemp = await lyfiApi.getKeepTemp(device);
      final fanMode = await lyfiApi.getFanMode(device);
      final fanPower = await lyfiApi.getFanManualPower(device);

      // Update properties with actual values (like notifyOfExternalUpdate in Mozilla WebThing)
      onOffProperty.value.notifyOfExternalUpdate(generalStatus.power);
      stateProperty.value.notifyOfExternalUpdate(lyfiStatus.state.name);
      modeProperty.value.notifyOfExternalUpdate(lyfiStatus.mode.name);
      colorProperty.value.notifyOfExternalUpdate(actualColor);
      scheduleProperty.value.notifyOfExternalUpdate(schedule);
      acclimationProperty.value.notifyOfExternalUpdate(acclimation);
      locationProperty.value.notifyOfExternalUpdate(location);
      correctionMethodProperty.value.notifyOfExternalUpdate(correctionMethod.name);
      timeZoneEnabledProperty.value.notifyOfExternalUpdate(timeZoneEnabled);
      timeZoneOffsetProperty.value.notifyOfExternalUpdate(timeZoneOffset);
      keepTempProperty.value.notifyOfExternalUpdate(keepTemp);
      temperatureProperty.value.notifyOfExternalUpdate(lyfiStatus.temperature);
      fanModeProperty.value.notifyOfExternalUpdate(fanMode.name);
      fanManualPowerProperty.value.notifyOfExternalUpdate(fanPower);

      logger?.d('LyfiThing: Successfully bound to hardware state');
    } catch (e, stackTrace) {
      // Continue with default values if hardware is not available
      logger?.e('LyfiThing: Warning - Failed to bind to hardware: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Lightweight periodic sync - only check critical properties
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (!isDisposed) {
        await _lightweightSync();
      } else {
        timer.cancel();
      }
    });
  }

  /// Lightweight sync - only check essential properties to minimize API calls
  Future<void> _lightweightSync() async {
    try {
      final generalStatus = await borneoApi.getGeneralDeviceStatus(device);

      onOffProperty.value.notifyOfExternalUpdate(generalStatus.power);

      // Sync mode and state
      final lyfiStatus = await lyfiApi.getLyfiStatus(device);
      modeProperty.value.notifyOfExternalUpdate(lyfiStatus.mode.name);
      stateProperty.value.notifyOfExternalUpdate(lyfiStatus.state.name);
      temperatureProperty.value.notifyOfExternalUpdate(lyfiStatus.temperature);
    } catch (e, stackTrace) {
      logger?.e('Lightweight sync failed: $e', error: e, stackTrace: stackTrace);
    }
  }

  // Track disposal and timer
  bool _disposed = false;
  bool get isDisposed => _disposed;
  Timer? _syncTimer;

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();

    super.dispose();
  }
}
