// dart format width=120

import 'dart:async';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/wot/borneo_props.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:logger/logger.dart';
import 'package:lw_wot/wot.dart';

/// LyfiThing extends WotThing following Mozilla WebThing initialization pattern
/// This class uses default values during construction and binds to actual hardware asynchronously
class LyfiThing extends WotThing implements WotWriteGuard, WotActionGuard {
  static const int kLightweightPeriodicIntervalSecs = 5;

  final Logger? logger;
  final Device device;
  final DeviceEventBus deviceEvents;
  final IBorneoDeviceApi borneoApi;
  final ILyfiDeviceApi lyfiApi;
  final bool Function()? canWrite;

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
  late final WotProperty<String> fanModeProperty;
  late final ObservableWotProperty<int, Object> fanManualPowerProperty;

  late final WotProperty<bool> cloudEnabledProperty;
  late final WotProperty<int> temporaryDurationProperty;
  late final WotProperty<List<ScheduledInstant>> sunScheduleProperty;
  late final WotProperty<List<SunCurveItem>> sunCurveProperty;
  late final WotProperty<int> currentTempProperty;
  late final WotProperty<LyfiDeviceInfo> deviceInfoProperty;
  late final WotProperty<bool> unscheduledProperty;
  late final WotProperty<int> temporaryRemainingProperty;
  late final WotProperty<int> fanPowerProperty;
  late final WotProperty<List<int>> manualColorProperty;
  late final WotProperty<List<int>> sunColorProperty;
  late final WotProperty<bool> acclimationActivatedProperty;
  late final WotProperty<bool> cloudActivatedProperty;
  late final WotProperty<double> powerCurrentProperty;

  late final WotProperty<double?> voltageProperty;
  late final WotProperty<double?> currentProperty;
  late final WotProperty<double?> powerProperty;

  // Temporary properties for refactoring - TODO: Remove after refactoring
  late final WotProperty<LyfiDeviceStatus> lyfiStatusProperty;
  late final WotProperty<GeneralBorneoDeviceStatus> generalStatusProperty;

  LyfiThing({
    required this.device,
    required this.deviceEvents,
    required this.borneoApi,
    required this.lyfiApi,
    required super.title,
    this.logger,
    this.canWrite,
  }) : super(id: device.id, type: ["OnOffSwitch", "Light"], description: "Lyfi LED lighting device");

  @override
  bool canWriteProperty(String propertyName) => canWrite?.call() ?? true;

  @override
  String? getWriteGuardError(String propertyName) => 'Device is offline or unbound.';

  @override
  bool canPerformAction(String actionName) => canWrite?.call() ?? true;

  @override
  String? getActionGuardError(String actionName) => 'Device is offline or unbound.';

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
    fanModeProperty = WotProperty<String>(
      thing: this,
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

    // Cloud enabled property
    cloudEnabledProperty = WotProperty<bool>(
      thing: this,
      name: 'cloudEnabled',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) => lyfiApi.setCloudEnabled(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Cloud Enabled',
        description: 'Controls cloud connectivity for remote management',
        readOnly: false,
      ),
    );
    addProperty(cloudEnabledProperty);

    // Temporary duration property
    temporaryDurationProperty = WotProperty<int>(
      thing: this,
      name: 'temporaryDuration',
      value: WotValue<int>(
        initialValue: 0, // Default 0 minutes
        valueForwarder: (update) => lyfiApi.setTemporaryDuration(device, Duration(minutes: update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Temporary Duration',
        description: 'Duration for temporary lighting mode in minutes',
        readOnly: false,
      ),
    );
    addProperty(temporaryDurationProperty);

    // Sun schedule property (read-only)
    sunScheduleProperty = WotProperty<List<ScheduledInstant>>(
      thing: this,
      name: 'sunSchedule',
      value: WotValue<List<ScheduledInstant>>(
        initialValue: [], // Default empty
        valueForwarder: (update) async {
          throw UnsupportedError('Sun schedule is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Sun Schedule',
        description: 'Computed sun-based lighting schedule',
        readOnly: true,
      ),
    );
    addProperty(sunScheduleProperty);

    // Sun curve property (read-only)
    sunCurveProperty = WotProperty<List<SunCurveItem>>(
      thing: this,
      name: 'sunCurve',
      value: WotValue<List<SunCurveItem>>(
        initialValue: [], // Default empty
        valueForwarder: (update) async {
          throw UnsupportedError('Sun curve is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Sun Curve',
        description: 'Sun brightness curve data points',
        readOnly: true,
      ),
    );
    addProperty(sunCurveProperty);

    // Current temperature property (read-only)
    currentTempProperty = WotProperty<int>(
      thing: this,
      name: 'currentTemp',
      value: WotValue<int>(
        initialValue: 25, // Default 25°C
        valueForwarder: (update) async {
          throw UnsupportedError('Current temperature is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Current Temperature',
        description: 'Current device temperature sensor reading in Celsius',
        readOnly: true,
      ),
    );
    addProperty(currentTempProperty);

    // Device info property (read-only)
    deviceInfoProperty = WotProperty<LyfiDeviceInfo>(
      thing: this,
      name: 'deviceInfo',
      value: WotValue<LyfiDeviceInfo>(
        initialValue: LyfiDeviceInfo(
          nominalPower: 0,
          channelCountMax: 0,
          channelCount: 0,
          channels: [],
        ), // Default empty
        valueForwarder: (update) async {
          throw UnsupportedError('Device info is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'Device Info',
        description: 'Device capabilities and channel metadata',
        readOnly: true,
      ),
    );
    addProperty(deviceInfoProperty);

    // Temporary Lyfi status property for refactoring - TODO: Remove after refactoring
    lyfiStatusProperty = WotProperty<LyfiDeviceStatus>(
      thing: this,
      name: 'lyfiStatus',
      value: WotValue<LyfiDeviceStatus>(
        initialValue: LyfiDeviceStatus(
          state: LyfiState.normal,
          mode: LyfiMode.manual,
          unscheduled: false,
          temporaryRemaining: Duration.zero,
          currentColor: [0, 0, 0, 0],
          manualColor: [0, 0, 0, 0],
          sunColor: [0, 0, 0, 0],
          temperature: null,
          powerCurrent: null,
        ), // Default values
        valueForwarder: (update) async {
          // Allow setting for now during refactoring
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'Lyfi Status',
        description: 'Temporary property for Lyfi device status during refactoring',
        readOnly: false,
      ),
    );
    addProperty(lyfiStatusProperty);

    // Temporary general status property for refactoring - TODO: Remove after refactoring
    generalStatusProperty = WotProperty<GeneralBorneoDeviceStatus>(
      thing: this,
      name: 'generalStatus',
      value: WotValue<GeneralBorneoDeviceStatus>(
        initialValue: GeneralBorneoDeviceStatus(
          timestamp: DateTime.now(),
          bootDuration: Duration.zero,
          timezone: '',
          wifiStatus: 0,
          btStatus: 0,
          serverStatus: 0,
          error: 0,
          shutdownReason: 0,
          power: false,
        ), // Default values
        valueForwarder: (update) async {
          throw UnsupportedError('General status is read-only during refactoring');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'General Status',
        description: 'Temporary property for general Borneo device status during refactoring',
        readOnly: true,
      ),
    );
    addProperty(generalStatusProperty);

    // Unscheduled property (read-only)
    unscheduledProperty = WotProperty<bool>(
      thing: this,
      name: 'unscheduled',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) async {
          throw UnsupportedError('Unscheduled status is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Unscheduled',
        description: 'Whether device is operating outside schedule',
        readOnly: true,
      ),
    );
    addProperty(unscheduledProperty);

    // Temporary remaining property (read-only)
    temporaryRemainingProperty = WotProperty<int>(
      thing: this,
      name: 'temporaryRemaining',
      value: WotValue<int>(
        initialValue: 0, // Default 0 seconds
        valueForwarder: (update) async {
          throw UnsupportedError('Temporary remaining is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Temporary Remaining',
        description: 'Seconds remaining in temporary mode',
        readOnly: true,
      ),
    );
    addProperty(temporaryRemainingProperty);

    // Fan power property (read-only)
    fanPowerProperty = WotProperty<int>(
      thing: this,
      name: 'fanPower',
      value: WotValue<int>(
        initialValue: 0, // Default 0%
        valueForwarder: (update) async {
          throw UnsupportedError('Fan power is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Fan Power',
        description: 'Current fan power level (0-100%)',
        minimum: 0,
        maximum: 100,
        readOnly: true,
      ),
    );
    addProperty(fanPowerProperty);

    // Manual color property (read-only)
    manualColorProperty = WotProperty<List<int>>(
      thing: this,
      name: 'manualColor',
      value: WotValue<List<int>>(
        initialValue: [0, 0, 0, 0], // Default all off
        valueForwarder: (update) async {
          throw UnsupportedError('Manual color is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Manual Color',
        description: 'Stored manual color values',
        readOnly: true,
      ),
    );
    addProperty(manualColorProperty);

    // Sun color property (read-only)
    sunColorProperty = WotProperty<List<int>>(
      thing: this,
      name: 'sunColor',
      value: WotValue<List<int>>(
        initialValue: [0, 0, 0, 0], // Default all off
        valueForwarder: (update) async {
          throw UnsupportedError('Sun color is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Sun Color',
        description: 'Current sun-simulated color values',
        readOnly: true,
      ),
    );
    addProperty(sunColorProperty);

    // Acclimation activated property (read-only)
    acclimationActivatedProperty = WotProperty<bool>(
      thing: this,
      name: 'acclimationActivated',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) async {
          throw UnsupportedError('Acclimation activated is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Acclimation Activated',
        description: 'Whether acclimation is currently running',
        readOnly: true,
      ),
    );
    addProperty(acclimationActivatedProperty);

    // Cloud activated property (read-only)
    cloudActivatedProperty = WotProperty<bool>(
      thing: this,
      name: 'cloudActivated',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) async {
          throw UnsupportedError('Cloud activated is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Cloud Activated',
        description: 'Whether cloud connection is active',
        readOnly: true,
      ),
    );
    addProperty(cloudActivatedProperty);

    // Power current property (read-only)
    powerCurrentProperty = WotProperty<double>(
      thing: this,
      name: 'powerCurrent',
      value: WotValue<double>(
        initialValue: 0.0, // Default 0W
        valueForwarder: (update) async {
          throw UnsupportedError('Power current is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'number',
        title: 'Power Current',
        description: 'Current power consumption in watts',
        readOnly: true,
      ),
    );
    addProperty(powerCurrentProperty);

    // Voltage property (read-only)
    voltageProperty = WotProperty<double?>(
      thing: this,
      name: 'voltage',
      value: WotValue<double?>(
        initialValue: null, // Default null
        valueForwarder: (update) async {
          throw UnsupportedError('Voltage is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'number',
        title: 'Voltage',
        description: 'Current voltage in volts',
        readOnly: true,
      ),
    );
    addProperty(voltageProperty);

    // Current property (read-only)
    currentProperty = WotProperty<double?>(
      thing: this,
      name: 'current',
      value: WotValue<double?>(
        initialValue: null, // Default null
        valueForwarder: (update) async {
          throw UnsupportedError('Current is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'number',
        title: 'Current',
        description: 'Current current in amperes',
        readOnly: true,
      ),
    );
    addProperty(currentProperty);

    // Power property (read-only)
    powerProperty = WotProperty<double?>(
      thing: this,
      name: 'power',
      value: WotValue<double?>(
        initialValue: null, // Default null
        valueForwarder: (update) async {
          throw UnsupportedError('Power is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'number',
        title: 'Power',
        description: 'Current power consumption in watts',
        readOnly: true,
      ),
    );
    addProperty(powerProperty);
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

      // Additional API calls for new properties
      final cloudEnabled = await lyfiApi.getCloudEnabled(device);
      final temporaryDuration = await lyfiApi.getTemporaryDuration(device);
      final sunSchedule = await lyfiApi.getSunSchedule(device);
      final sunCurve = await lyfiApi.getSunCurve(device);
      // final currentTemp = await lyfiApi.getCurrentTemp(device); // Use lyfiStatus.temperature
      // final deviceInfo = await lyfiApi.getDeviceInfo(device); // Skip for now

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

      // Update new properties
      cloudEnabledProperty.value.notifyOfExternalUpdate(cloudEnabled);
      temporaryDurationProperty.value.notifyOfExternalUpdate(temporaryDuration.inMinutes);
      sunScheduleProperty.value.notifyOfExternalUpdate(sunSchedule);
      sunCurveProperty.value.notifyOfExternalUpdate(sunCurve);
      currentTempProperty.value.notifyOfExternalUpdate(lyfiStatus.temperature ?? 25);
      // deviceInfoProperty.value.notifyOfExternalUpdate(deviceInfo);
      unscheduledProperty.value.notifyOfExternalUpdate(lyfiStatus.unscheduled);
      temporaryRemainingProperty.value.notifyOfExternalUpdate(lyfiStatus.temporaryRemaining.inSeconds);
      fanPowerProperty.value.notifyOfExternalUpdate(lyfiStatus.fanPower ?? 0);
      manualColorProperty.value.notifyOfExternalUpdate(lyfiStatus.manualColor);
      sunColorProperty.value.notifyOfExternalUpdate(lyfiStatus.sunColor);
      acclimationActivatedProperty.value.notifyOfExternalUpdate(lyfiStatus.acclimationActivated);
      cloudActivatedProperty.value.notifyOfExternalUpdate(lyfiStatus.cloudActivated);
      powerCurrentProperty.value.notifyOfExternalUpdate(lyfiStatus.powerCurrent ?? 0.0);

      // Update power measurement properties
      voltageProperty.value.notifyOfExternalUpdate(generalStatus.powerVoltage);
      currentProperty.value.notifyOfExternalUpdate(lyfiStatus.powerCurrent);
      powerProperty.value.notifyOfExternalUpdate(
        generalStatus.powerVoltage != null && lyfiStatus.powerCurrent != null
            ? generalStatus.powerVoltage! * lyfiStatus.powerCurrent!
            : null,
      );

      logger?.d('LyfiThing: Successfully bound to hardware state');
    } catch (e, stackTrace) {
      // Continue with default values if hardware is not available
      logger?.e('LyfiThing: Warning - Failed to bind to hardware: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Lightweight periodic sync - only check critical properties
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(seconds: kLightweightPeriodicIntervalSecs), (timer) async {
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

      // Sync additional critical properties
      currentTempProperty.value.notifyOfExternalUpdate(lyfiStatus.temperature ?? 0);
      fanPowerProperty.value.notifyOfExternalUpdate(lyfiStatus.fanPower ?? 0);
      unscheduledProperty.value.notifyOfExternalUpdate(lyfiStatus.unscheduled);
      temporaryRemainingProperty.value.notifyOfExternalUpdate(lyfiStatus.temporaryRemaining.inSeconds);
      acclimationActivatedProperty.value.notifyOfExternalUpdate(lyfiStatus.acclimationActivated);
      cloudActivatedProperty.value.notifyOfExternalUpdate(lyfiStatus.cloudActivated);
      powerCurrentProperty.value.notifyOfExternalUpdate(lyfiStatus.powerCurrent ?? 0.0);

      // Update power measurement properties
      voltageProperty.value.notifyOfExternalUpdate(generalStatus.powerVoltage);
      currentProperty.value.notifyOfExternalUpdate(
        generalStatus.powerVoltage != null && lyfiStatus.powerCurrent != null ? lyfiStatus.powerCurrent! : null,
      );
      powerProperty.value.notifyOfExternalUpdate(
        generalStatus.powerVoltage != null && lyfiStatus.powerCurrent != null
            ? generalStatus.powerVoltage! * lyfiStatus.powerCurrent!
            : null,
      );
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
