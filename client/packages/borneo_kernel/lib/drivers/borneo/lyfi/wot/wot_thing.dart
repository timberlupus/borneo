// dart format width=120

import 'dart:async';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/wot/borneo_props.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot/wot_actions.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:logger/logger.dart';
import 'package:lw_wot/wot.dart';

/// LyfiThing extends WotThing following Mozilla WebThing initialization pattern
/// This class uses default values during construction and binds to actual hardware asynchronously
class LyfiThing extends WotThing implements WotWriteGuard, WotActionGuard {
  static const int kLightweightPeriodicIntervalSecs = 1;
  static const int kLowFrequencyPeriodicIntervalSecs = 15;

  final IKernel kernel;
  final Logger? logger;
  final Device device;
  final DeviceEventBus deviceEvents;
  IBorneoDeviceApi? borneoApi;
  ILyfiDeviceApi? lyfiApi;
  bool canWrite() => kernel.isBound(device.id);
  bool isOffline = false;

  LyfiThing({
    required this.kernel,
    required this.device,
    required this.deviceEvents,
    required this.borneoApi,
    required this.lyfiApi,
    required super.title,
    this.logger,
  }) : super(id: device.id, type: ["OnOffSwitch", "Light"], description: "Lyfi LED lighting device") {
    _createPropertiesWithDefaults();
    _createActions();
  }

  factory LyfiThing.offline({
    required IKernel kernel,
    required Device device,
    required DeviceEventBus deviceEvents,
    required String title,
    Logger? logger,
  }) {
    return LyfiThing(
      kernel: kernel,
      device: device,
      deviceEvents: deviceEvents,
      borneoApi: null,
      lyfiApi: null,
      title: title,
      logger: logger,
    )..isOffline = true;
  }

  Future<void> bindToOnlineApis(
    IBorneoDeviceApi newBorneoApi,
    ILyfiDeviceApi newLyfiApi, {
    CancellationToken? cancelToken,
  }) async {
    if (!isOffline) return;
    borneoApi = newBorneoApi;
    lyfiApi = newLyfiApi;
    isOffline = false;
    findProperty('online')?.value.notifyOfExternalUpdate(true);
    // Re-bind to hardware
    await _bindToHardware();
  }

  @override
  bool canWriteProperty(String propertyName) => canWrite.call();

  @override
  String? getWriteGuardError(String propertyName) => 'Device is offline or unbound.';

  @override
  bool canPerformAction(String actionName) => canWrite.call();

  @override
  String? getActionGuardError(String actionName) => 'Device is offline or unbound.';

  /// Mozilla WebThing style initialization - sync constructor with async hardware binding
  Future<void> initialize({CancellationToken? cancelToken}) async {
    if (!isOffline) {
      await _bindToHardware().asCancellable(cancelToken);
    }

    _setupPeriodicSync();
  }

  /// Create properties with reasonable defaults first, then bind to hardware
  /// This follows Mozilla WebThing pattern of creating Value objects with initial values
  void _createPropertiesWithDefaults() {
    // Online property - indicates connection status
    final onlineProperty = WotProperty<bool>(
      thing: this,
      name: 'online',
      value: WotValue<bool>(
        initialValue: !isOffline,
        valueForwarder: (_) => throw UnsupportedError('Online status is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Online',
        description: 'Device connection status',
        readOnly: true,
      ),
    );
    addProperty(onlineProperty);

    // Power property with default false, will be updated when hardware is ready
    final onProperty = ObservableWotProperty<bool, DevicePowerOnOffChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'on',
      value: WotValue<bool>(
        initialValue: false, // Default value, updated in _bindToHardware
        valueForwarder: (update) => isOffline ? Future.value() : unawaited(borneoApi!.setOnOff(device, update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'On/Off',
        description: 'Power on/off state',
        readOnly: false,
      ),
      eventName: 'onChanged',
      mapper: (event) => event.onOff,
    );
    addProperty(onProperty);

    // State property with default state
    final stateProperty = ObservableWotProperty<String, LyfiStateChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'state',
      value: WotValue<String>(
        initialValue: LyfiState.values.first.name, // Default state
        valueForwarder: (update) async {
          await lyfiApi!.switchState(device, LyfiState.fromString(update));
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
    final modeProperty = ObservableWotProperty<String, LyfiModeChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'mode',
      value: WotValue<String>(
        initialValue: LyfiMode.values.first.name, // Default mode
        valueForwarder: (update) => lyfiApi!.switchMode(device, LyfiMode.fromString(update)),
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
    final colorProperty = WotProperty<List<int>>(
      thing: this,
      name: 'color',
      value: WotValue<List<int>>(
        initialValue: [], // Default 4-channel all off
        valueForwarder: (update) => lyfiApi!.setColor(device, update),
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
    final scheduleProperty = ObservableWotProperty<ScheduleTable, LyfiScheduleChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'schedule',
      value: WotValue<ScheduleTable>(
        initialValue: [], // Default empty schedule
        valueForwarder: (update) => lyfiApi!.setSchedule(device, update),
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
    final acclimationProperty = ObservableWotProperty<AcclimationSettings, LyfiAcclimationChangedEvent>(
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
        valueForwarder: (_) => throw UnsupportedError('Acclimation is read-only; use action to update'),
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'Acclimation',
        description: 'LED acclimation settings for gradual brightness increase',
        readOnly: true,
      ),
      eventName: 'acclimationChanged',
      mapper: (event) => event.settings,
    );
    addProperty(acclimationProperty);

    // Location property
    final locationProperty = ObservableWotProperty<GeoLocation?, LyfiLocationChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'location',
      value: WotValue<GeoLocation?>(
        initialValue: null, // Default no location
        valueForwarder: (update) async {
          if (update != null) {
            await lyfiApi!.setLocation(device, update);
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
    final correctionMethodProperty = ObservableWotProperty<String, LyfiCorrectionMethodChangedEvent>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'correctionMethod',
      value: WotValue<String>(
        initialValue: LedCorrectionMethod.log.name,
        valueForwarder: (update) =>
            lyfiApi!.setCorrectionMethod(device, LedCorrectionMethodExtension.fromString(update)),
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

    // Timezone property (read-only)
    final timezoneProperty = WotProperty<String>(
      thing: this,
      name: 'timezone',
      value: WotValue<String>(initialValue: '', valueForwarder: (_) => throw UnsupportedError('Timezone is read-only')),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Timezone',
        description: 'Device timezone name',
        readOnly: true,
      ),
    );
    addProperty(timezoneProperty);

    // Timezone enabled property
    final timezoneEnabledProperty = WotProperty<bool>(
      thing: this,
      name: 'timezoneEnabled',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) => lyfiApi!.setTimeZoneEnabled(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Timezone Enabled',
        description: 'Whether timezone offset is enabled',
        readOnly: false,
      ),
    );
    addProperty(timezoneEnabledProperty);

    // Timezone offset property
    final timezoneOffsetProperty = WotProperty<int>(
      thing: this,
      name: 'timezoneOffset',
      value: WotValue<int>(
        initialValue: 0, // Default 0 offset
        valueForwarder: (update) => lyfiApi!.setTimeZoneOffset(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Timezone Offset',
        description: 'Timezone offset in seconds from UTC',
        readOnly: false,
      ),
    );
    addProperty(timezoneOffsetProperty);

    // Keep temperature property
    final keepTempProperty = WotProperty<int>(
      thing: this,
      name: 'keepTemp',
      value: WotValue<int>(
        initialValue: 75, // Default 75°C
        valueForwarder: (_) => throw UnsupportedError('Keep temperature is read-only for safety'),
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
    final temperatureProperty = WotProperty<int?>(
      thing: this,
      name: 'temperature',
      value: WotValue<int?>(
        initialValue: null, // Default null
        valueForwarder: (update) => throw UnsupportedError('Temperature is read-only'),
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
    final fanModeProperty = WotProperty<String>(
      thing: this,
      name: 'fanMode',
      value: WotValue<String>(
        initialValue: FanMode.pid.name, // Default PID mode
        valueForwarder: (update) => lyfiApi!.setFanMode(device, FanMode.values.firstWhere((e) => e.name == update)),
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
    final fanManualPowerProperty = ObservableWotProperty<int, Object>(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'fanManualPower',
      value: WotValue<int>(
        initialValue: 0, // Default 0% power
        valueForwarder: (update) => lyfiApi!.setFanManualPower(device, update),
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
    final cloudEnabledProperty = WotProperty<bool>(
      thing: this,
      name: 'cloudEnabled',
      value: WotValue<bool>(
        initialValue: false, // Default false
        valueForwarder: (update) => lyfiApi!.setCloudEnabled(device, update),
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
    final temporaryDurationProperty = WotProperty<Duration>(
      thing: this,
      name: 'temporaryDuration',
      value: WotValue<Duration>(
        initialValue: Duration.zero, // Default zero duration
        valueForwarder: (update) => lyfiApi!.setTemporaryDuration(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'duration',
        title: 'Temporary Duration',
        description: 'Duration for temporary lighting mode',
        readOnly: false,
      ),
    );
    addProperty(temporaryDurationProperty);

    // Sun schedule property (read-only)
    final sunScheduleProperty = WotProperty<List<ScheduledInstant>>(
      thing: this,
      name: 'sunSchedule',
      value: WotValue<List<ScheduledInstant>>(
        initialValue: [], // Default empty
        valueForwarder: (update) => throw UnsupportedError('Sun schedule is read-only'),
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
    final sunCurveProperty = WotProperty<List<SunCurveItem>>(
      thing: this,
      name: 'sunCurve',
      value: WotValue<List<SunCurveItem>>(
        initialValue: [], // Default empty
        valueForwarder: (_) => throw UnsupportedError('Sun curve is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Sun Curve',
        description: 'Sun brightness curve data points',
        readOnly: true,
      ),
    );
    addProperty(sunCurveProperty);

    // Moon config property (read-only)
    final moonConfigProperty = WotProperty<MoonConfig>(
      thing: this,
      name: 'moonConfig',
      value: WotValue<MoonConfig>(
        initialValue: MoonConfig(enabled: false, color: [0, 0, 0, 0]),
        valueForwarder: (_) => throw UnsupportedError('Moon config is read-only; use action to update'),
      ),
      metadata: WotPropertyMetadata(
        title: 'Moon Configuration',
        type: 'object',
        description: 'Configuration for moon simulation including enabled state and color',
        readOnly: true,
      ),
    );
    addProperty(moonConfigProperty);

    // Moon status property (read-only)
    final moonStatusProperty = WotProperty<MoonStatus>(
      thing: this,
      name: 'moonStatus',
      value: WotValue<MoonStatus>(initialValue: MoonStatus(phaseAngle: 0.0, illumination: 0.0)),
      metadata: WotPropertyMetadata(
        title: 'Moon Status',
        type: 'object',
        description: 'Current moon phase angle and illumination percentage',
        readOnly: true,
      ),
    );
    addProperty(moonStatusProperty);

    // Moon schedule property (read-only)
    final moonScheduleProperty = WotProperty<List<ScheduledInstant>>(
      thing: this,
      name: 'moonSchedule',
      value: WotValue<List<ScheduledInstant>>(
        initialValue: [],
        valueForwarder: (_) => throw UnsupportedError('Moon schedule is read-only'),
      ),
      metadata: WotPropertyMetadata(
        title: 'Moon Schedule',
        type: 'array',
        description: 'Schedule for moon simulation',
        readOnly: true,
      ),
    );
    addProperty(moonScheduleProperty);

    // Moon curve property (read-only)
    final moonCurveProperty = WotProperty<List<MoonCurveItem>>(
      thing: this,
      name: 'moonCurve',
      value: WotValue<List<MoonCurveItem>>(
        initialValue: [],
        valueForwarder: (_) => throw UnsupportedError('Moon curve is read-only'),
      ),
      metadata: WotPropertyMetadata(
        title: 'Moon Curve',
        type: 'array',
        description: 'Brightness curve for moon simulation',
        readOnly: true,
      ),
    );
    addProperty(moonCurveProperty);

    // Current temperature property (read-only)
    final currentTempProperty = WotProperty<int>(
      thing: this,
      name: 'currentTemp',
      value: WotValue<int>(
        initialValue: 25, // Default 25°C
        valueForwarder: (_) => throw UnsupportedError('Current temperature is read-only'),
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
    final lyfiDeviceInfoProperty = WotProperty<LyfiDeviceInfo>(
      thing: this,
      name: 'lyfiDeviceInfo',
      value: WotValue<LyfiDeviceInfo>(
        initialValue: LyfiDeviceInfo(
          nominalPower: null,
          channelCountMax: 0,
          channelCount: 0,
          channels: [],
        ), // Default empty
        valueForwarder: (_) => throw UnsupportedError('Device info is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'LyFi Device Info',
        description: 'LyFi Device capabilities and channel metadata',
        readOnly: true,
      ),
    );
    addProperty(lyfiDeviceInfoProperty);

    // Temporary Lyfi status property for refactoring - TODO: Remove after refactoring
    final lyfiStatusProperty = WotProperty<LyfiDeviceStatus>(
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

    // General device info property (read-only)
    final generalDeviceInfoProperty = WotProperty<GeneralBorneoDeviceInfo?>(
      thing: this,
      name: 'generalDeviceInfo',
      value: WotValue<GeneralBorneoDeviceInfo?>(
        initialValue: null,
        valueForwarder: (update) async {
          throw UnsupportedError('General device info is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'object',
        title: 'General Device Info',
        description: 'General Borneo device information',
        readOnly: true,
      ),
    );
    addProperty(generalDeviceInfoProperty);

    // Temporary general status property for refactoring - TODO: Remove after refactoring
    final generalStatusProperty = WotProperty<GeneralBorneoDeviceStatus>(
      thing: this,
      name: 'generalStatus',
      value: WotValue<GeneralBorneoDeviceStatus>(
        initialValue: GeneralBorneoDeviceStatus(
          timestamp: DateTime.now().toUtc(),
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
    final unscheduledProperty = WotProperty<bool>(
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
    final temporaryRemainingProperty = WotProperty<Duration>(
      thing: this,
      name: 'temporaryRemaining',
      value: WotValue<Duration>(
        initialValue: Duration.zero, // Default zero duration
        valueForwarder: (update) async {
          throw UnsupportedError('Temporary remaining is read-only');
        },
      ),
      metadata: WotPropertyMetadata(
        type: 'duration',
        title: 'Temporary Remaining',
        description: 'Time remaining in temporary mode',
        readOnly: true,
      ),
    );
    addProperty(temporaryRemainingProperty);

    // Fan power property (read-only)
    final fanPowerProperty = WotProperty<int>(
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
    final manualColorProperty = WotProperty<List<int>>(
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
    final sunColorProperty = WotProperty<List<int>>(
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

    // Acclimation enabled property (read-only)
    final acclimationEnabledProperty = WotProperty<bool>(
      thing: this,
      name: 'acclimationEnabled',
      value: WotValue<bool>(
        initialValue: false,
        valueForwarder: (update) => throw UnsupportedError('Acclimation enabled is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Acclimation Enabled',
        description: 'Whether acclimation is enabled',
        readOnly: true,
      ),
    );
    addProperty(acclimationEnabledProperty);

    // Acclimation activated property (read-only)
    final acclimationActivatedProperty = WotProperty<bool>(
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
    final cloudActivatedProperty = WotProperty<bool>(
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

    // Voltage property (read-only)
    final voltageProperty = WotProperty<double?>(
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
    final currentProperty = WotProperty<double?>(
      thing: this,
      name: 'current',
      value: WotValue<double?>(
        initialValue: null, // Default null
        valueForwarder: (update) async => throw UnsupportedError('Current is read-only'),
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
    final powerProperty = WotProperty<double?>(
      thing: this,
      name: 'power',
      value: WotValue<double?>(
        initialValue: null, // Default null
        valueForwarder: (update) async => throw UnsupportedError('Power is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'number',
        title: 'Power',
        description: 'Current power consumption in watts',
        readOnly: true,
      ),
    );
    addProperty(powerProperty);

    // Power behavior property (read-only)
    final powerBehaviorProperty = WotProperty<PowerBehavior>(
      thing: this,
      name: 'powerBehavior',
      value: WotValue<PowerBehavior>(
        initialValue: PowerBehavior.lastPowerState, // Default to last power state
        valueForwarder: (_) => throw UnsupportedError('Power behavior is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Power Behavior',
        description: 'Behavior when power is restored after an outage',
        enumValues: PowerBehavior.values.map((e) => e.name).toList(),
        readOnly: true,
      ),
    );
    addProperty(powerBehaviorProperty);

    // Timestamp property (read-only)
    final timestampProperty = WotProperty<DateTime>(
      thing: this,
      name: 'timestamp',
      value: WotValue<DateTime>(
        initialValue: DateTime.now().toUtc(),
        valueForwarder: (_) => throw UnsupportedError('Timestamp is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Timestamp',
        description: 'Device timestamp (UTC)',
        readOnly: true,
      ),
    );
    addProperty(timestampProperty);
  }

  void _createActions() {
    // Switch state action
    addAvailableAction(
      'switchState',
      WotActionMetadata(
        title: 'Switch State',
        description: 'Switch the device to a different operating state',
        input: {'state': 'string'},
      ),
      (thing, input) {
        final stateName = input['state'] as String;
        final targetState = LyfiState.values.firstWhere((e) => e.name == stateName);
        return LyfiSwitchStateAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          targetState: targetState,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );

    // Switch mode action
    addAvailableAction(
      'switchMode',
      WotActionMetadata(
        title: 'Switch Mode',
        description: 'Switch the device to a different lighting mode',
        input: {'mode': 'string', 'color': 'array'},
      ),
      (thing, input) {
        final modeName = input['mode'] as String;
        final targetMode = LyfiMode.values.firstWhere((e) => e.name == modeName);
        final color = input['color'] as List<int>?;
        return LyfiSwitchModeAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          targetMode: targetMode,
          lyfiApi: lyfiApi!,
          device: device,
          color: color,
        );
      },
    );

    // Set color action
    addAvailableAction(
      'setColor',
      WotActionMetadata(
        title: 'Set Color',
        description: 'Set the LED channel brightness values',
        input: {'color': 'array'},
      ),
      (thing, input) {
        final color = input['color'] as List<int>;
        return LyfiSetColorAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          color: color,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );

    // Set schedule action
    addAvailableAction(
      'setSchedule',
      WotActionMetadata(
        title: 'Set Schedule',
        description: 'Set the lighting schedule with time instants and colors',
        input: {'schedule': 'array'},
      ),
      (thing, input) {
        final scheduleData = input['schedule'] as List<dynamic>;
        final schedule = scheduleData.map((s) => ScheduledInstant.fromMap(s as Map<String, dynamic>)).toList();
        return LyfiSetScheduleAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          schedule: schedule,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );

    // Set acclimation action
    addAvailableAction(
      'setAcclimation',
      WotActionMetadata(
        title: 'Set Acclimation',
        description: 'Configure acclimation settings for gradual brightness increase',
        input: {'enabled': 'boolean', 'startTimestamp': 'number', 'startPercent': 'number', 'days': 'number'},
      ),
      (thing, input) {
        final settings = AcclimationSettings(
          enabled: input['enabled'] as bool,
          startTimestamp: DateTime.fromMillisecondsSinceEpoch((input['startTimestamp'] as num).toInt() * 1000),
          startPercent: input['startPercent'] as int,
          days: input['days'] as int,
        );
        return LyfiSetAcclimationAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          settings: settings,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );

    // Set location action
    addAvailableAction(
      'setLocation',
      WotActionMetadata(
        title: 'Set Location',
        description: 'Set the geographic location for sun simulation',
        input: {'lat': 'number', 'lng': 'number'},
      ),
      (thing, input) {
        final location = GeoLocation(lat: input['lat'] as double, lng: input['lng'] as double);
        return LyfiSetLocationAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          location: location,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );

    // Set correction method action
    addAvailableAction(
      'setCorrectionMethod',
      WotActionMetadata(
        title: 'Set Correction Method',
        description: 'Set the LED brightness correction method',
        input: {'method': 'string'},
      ),
      (thing, input) {
        final methodName = input['method'] as String;
        final method = LedCorrectionMethod.values.firstWhere((e) => e.name == methodName);
        return LyfiSetCorrectionMethodAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          method: method,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );

    // Set power behavior action
    addAvailableAction(
      'setPowerBehavior',
      WotActionMetadata(
        title: 'Set Power Behavior',
        description: 'Set the behavior when power is restored after an outage',
        input: {'behavior': 'string'},
      ),
      (thing, input) {
        final behaviorName = input['behavior'] as String;
        final behavior = PowerBehavior.values.firstWhere((e) => e.name == behaviorName);
        return LyfiSetPowerBehaviorAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          behavior: behavior,
          borneoApi: borneoApi!,
          device: device,
        );
      },
    );

    // Set moon config action
    addAvailableAction(
      'setMoonConfig',
      WotActionMetadata(
        title: 'Set Moon Configuration',
        description: 'Set the moon simulation configuration including enabled state and color',
        input: {'enabled': 'boolean', 'color': 'array'},
      ),
      (thing, input) {
        final config = MoonConfig(enabled: input['enabled'] as bool, color: List<int>.from(input['color'] as List));
        return LyfiSetMoonConfigAction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          thing: thing,
          config: config,
          lyfiApi: lyfiApi!,
          device: device,
        );
      },
    );
  }

  /// Bind properties to actual hardware state (like Mozilla WebThing ready callback)
  Future<void> _bindToHardware() async {
    if (isOffline || borneoApi == null || lyfiApi == null) return;
    // Get actual device state and update property values
    final generalStatus = await borneoApi!.getGeneralDeviceStatus(device);
    final generalDeviceInfo = await borneoApi!.getGeneralDeviceInfo(device);
    final lyfiStatus = await lyfiApi!.getLyfiStatus(device);
    final schedule = await lyfiApi!.getSchedule(device);
    final acclimation = await lyfiApi!.getAcclimation(device);
    final location = await lyfiApi!.getLocation(device);
    final correctionMethod = await lyfiApi!.getCorrectionMethod(device);
    final timeZoneEnabled = await lyfiApi!.getTimeZoneEnabled(device);
    final timeZoneOffset = await lyfiApi!.getTimeZoneOffset(device);
    final keepTemp = await lyfiApi!.getKeepTemp(device);
    final fanMode = await lyfiApi!.getFanMode(device);
    final fanPower = await lyfiApi!.getFanManualPower(device);

    // Additional API calls for new properties
    final cloudEnabled = await lyfiApi!.getCloudEnabled(device);
    final temporaryDuration = await lyfiApi!.getTemporaryDuration(device);
    final sunSchedule = await lyfiApi!.getSunSchedule(device);

    final powerBehavior = await borneoApi!.getPowerBehavior(device);
    final deviceInfo = await lyfiApi!.getLyfiInfo(device);
    // final currentTemp = await lyfiApi.getCurrentTemp(device); // Use lyfiStatus.temperature
    // final deviceInfo = await lyfiApi.getDeviceInfo(device); // Skip for now

    try {
      final sunCurve = await lyfiApi!.getSunCurve(device);
      findProperty('sunCurve')?.value.notifyOfExternalUpdate(sunCurve);
    } catch (e) {
      logger?.w("Failed to get Sun curve: $e");
    }

    try {
      final moonCurve = await lyfiApi!.getMoonCurve(device);
      findProperty('moonCurve')?.value.notifyOfExternalUpdate(moonCurve);
    } catch (e) {
      logger?.w("Failed to get Moon curve: $e");
    }

    // Update properties with actual values (like notifyOfExternalUpdate in Mozilla WebThing)
    findProperty('on')?.value.notifyOfExternalUpdate(generalStatus.power);
    findProperty('state')?.value.notifyOfExternalUpdate(lyfiStatus.state.name);
    findProperty('mode')?.value.notifyOfExternalUpdate(lyfiStatus.mode.name);
    findProperty('color')?.value.notifyOfExternalUpdate(lyfiStatus.currentColor);
    findProperty('schedule')?.value.notifyOfExternalUpdate(schedule);
    findProperty('acclimation')?.value.notifyOfExternalUpdate(acclimation);
    findProperty('location')?.value.notifyOfExternalUpdate(location);
    findProperty('correctionMethod')?.value.notifyOfExternalUpdate(correctionMethod.name);
    findProperty('timezone')?.value.notifyOfExternalUpdate(generalStatus.timezone);
    findProperty('timezoneEnabled')?.value.notifyOfExternalUpdate(timeZoneEnabled);
    findProperty('timezoneOffset')?.value.notifyOfExternalUpdate(timeZoneOffset);
    findProperty('keepTemp')?.value.notifyOfExternalUpdate(keepTemp);
    findProperty('temperature')?.value.notifyOfExternalUpdate(lyfiStatus.temperature);
    findProperty('fanMode')?.value.notifyOfExternalUpdate(fanMode.name);
    findProperty('fanManualPower')?.value.notifyOfExternalUpdate(fanPower);

    findProperty('cloudEnabled')?.value.notifyOfExternalUpdate(cloudEnabled);
    findProperty('temporaryDuration')?.value.notifyOfExternalUpdate(temporaryDuration);
    findProperty('sunSchedule')?.value.notifyOfExternalUpdate(sunSchedule);

    // Additional moon API calls
    final moonConfig = await lyfiApi!.getMoonConfig(device);
    final moonSchedule = await lyfiApi!.getMoonSchedule(device);
    final moonStatus = await lyfiApi!.getMoonStatus(device);

    findProperty('moonConfig')?.value.notifyOfExternalUpdate(moonConfig);
    findProperty('moonSchedule')?.value.notifyOfExternalUpdate(moonSchedule);
    findProperty('moonStatus')?.value.notifyOfExternalUpdate(moonStatus);

    findProperty('currentTemp')?.value.notifyOfExternalUpdate(lyfiStatus.temperature ?? 25);
    findProperty('lyfiDeviceInfo')?.value.notifyOfExternalUpdate(deviceInfo);
    findProperty('unscheduled')?.value.notifyOfExternalUpdate(lyfiStatus.unscheduled);
    findProperty('temporaryRemaining')?.value.notifyOfExternalUpdate(lyfiStatus.temporaryRemaining);
    findProperty('fanPower')?.value.notifyOfExternalUpdate(lyfiStatus.fanPower ?? 0);
    findProperty('manualColor')?.value.notifyOfExternalUpdate(lyfiStatus.manualColor);
    findProperty('sunColor')?.value.notifyOfExternalUpdate(lyfiStatus.sunColor);
    findProperty('acclimationEnabled')?.value.notifyOfExternalUpdate(lyfiStatus.acclimationEnabled);
    findProperty('acclimationActivated')?.value.notifyOfExternalUpdate(lyfiStatus.acclimationActivated);
    findProperty('cloudActivated')?.value.notifyOfExternalUpdate(lyfiStatus.cloudActivated);

    // Update power measurement properties
    findProperty('voltage')?.value.notifyOfExternalUpdate(generalStatus.powerVoltage);
    findProperty('current')?.value.notifyOfExternalUpdate(lyfiStatus.powerCurrent);
    findProperty('power')?.value.notifyOfExternalUpdate(
      generalStatus.powerVoltage != null && lyfiStatus.powerCurrent != null
          ? generalStatus.powerVoltage! * lyfiStatus.powerCurrent!
          : null,
    );

    // Update power behavior property
    findProperty('powerBehavior')?.value.notifyOfExternalUpdate(powerBehavior);

    // Update timestamp property
    findProperty('timestamp')?.value.notifyOfExternalUpdate(generalStatus.timestamp);

    // Update status properties
    findProperty('lyfiStatus')?.value.notifyOfExternalUpdate(lyfiStatus);
    findProperty('generalDeviceInfo')?.value.notifyOfExternalUpdate(generalDeviceInfo);
    findProperty('generalStatus')?.value.notifyOfExternalUpdate(generalStatus);
  }

  /// Lightweight periodic sync - only check critical properties
  void _setupPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(seconds: kLightweightPeriodicIntervalSecs), (timer) async {
      if (!isDisposed && !isOffline) {
        await _lightweightSync();
      } else {
        timer.cancel();
      }
    });

    _lowFrequencySyncTimer = Timer.periodic(Duration(seconds: kLowFrequencyPeriodicIntervalSecs), (timer) async {
      if (!isDisposed && !isOffline) {
        await _lowFrequencySync();
      } else {
        timer.cancel();
      }
    });
  }

  /// Lightweight sync - only check essential properties to minimize API calls
  Future<void> _lightweightSync() async {
    try {
      final generalStatus = await borneoApi!.getGeneralDeviceStatus(device);

      findProperty('on')?.value.notifyOfExternalUpdate(generalStatus.power);

      // Sync mode and state
      final lyfiStatus = await lyfiApi!.getLyfiStatus(device);
      findProperty('mode')?.value.notifyOfExternalUpdate(lyfiStatus.mode.name);
      findProperty('state')?.value.notifyOfExternalUpdate(lyfiStatus.state.name);
      findProperty('temperature')?.value.notifyOfExternalUpdate(lyfiStatus.temperature);
      findProperty('color')?.value.notifyOfExternalUpdate(lyfiStatus.currentColor);

      // Sync additional critical properties
      findProperty('currentTemp')?.value.notifyOfExternalUpdate(lyfiStatus.temperature ?? 0);
      findProperty('fanPower')?.value.notifyOfExternalUpdate(lyfiStatus.fanPower ?? 0);
      findProperty('unscheduled')?.value.notifyOfExternalUpdate(lyfiStatus.unscheduled);
      findProperty('temporaryRemaining')?.value.notifyOfExternalUpdate(lyfiStatus.temporaryRemaining);
      findProperty('cloudActivated')?.value.notifyOfExternalUpdate(lyfiStatus.cloudActivated);
      findProperty('sunColor')?.value.notifyOfExternalUpdate(lyfiStatus.sunColor);
      findProperty('acclimationEnabled')?.value.notifyOfExternalUpdate(lyfiStatus.acclimationEnabled);

      // Update power measurement properties
      findProperty('voltage')?.value.notifyOfExternalUpdate(generalStatus.powerVoltage);
      findProperty('current')?.value.notifyOfExternalUpdate(
        generalStatus.powerVoltage != null && lyfiStatus.powerCurrent != null ? lyfiStatus.powerCurrent! : null,
      );
      findProperty('power')?.value.notifyOfExternalUpdate(
        generalStatus.powerVoltage != null && lyfiStatus.powerCurrent != null
            ? generalStatus.powerVoltage! * lyfiStatus.powerCurrent!
            : null,
      );

      // Update status properties
      findProperty('lyfiStatus')?.value.notifyOfExternalUpdate(lyfiStatus);
      findProperty('generalStatus')?.value.notifyOfExternalUpdate(generalStatus);
      findProperty('timestamp')?.value.notifyOfExternalUpdate(generalStatus.timestamp);
      findProperty('timezone')?.value.notifyOfExternalUpdate(generalStatus.timezone);
    } catch (e, stackTrace) {
      logger?.w('Lightweight sync failed: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _lowFrequencySync() async {
    if (lyfiApi == null) {
      return;
    }
    try {
      final lyfiStatus = await lyfiApi!.getLyfiStatus(device);
      final deviceInfo = await lyfiApi!.getLyfiInfo(device);
      findProperty('acclimationEnabled')?.value.notifyOfExternalUpdate(lyfiStatus.acclimationEnabled);
      findProperty('acclimationActivated')?.value.notifyOfExternalUpdate(lyfiStatus.acclimationActivated);
      findProperty('lyfiDeviceInfo')?.value.notifyOfExternalUpdate(deviceInfo);

      if (borneoApi != null) {
        final generalDeviceInfo = await borneoApi!.getGeneralDeviceInfo(device);
        findProperty('generalDeviceInfo')?.value.notifyOfExternalUpdate(generalDeviceInfo);
      }

      switch (lyfiStatus.mode) {
        case LyfiMode.manual:
          {
            final manualColor = lyfiStatus.manualColor;
            findProperty('manualColor')?.value.notifyOfExternalUpdate(manualColor);
          }
          break;

        case LyfiMode.scheduled:
          {
            final schedule = await lyfiApi!.getSchedule(device);
            findProperty('schedule')?.value.notifyOfExternalUpdate(schedule);
          }
          break;

        case LyfiMode.sun:
          {
            final sunSchedule = await lyfiApi!.getSunSchedule(device);
            findProperty('sunSchedule')?.value.notifyOfExternalUpdate(sunSchedule);
            final sunCurve = await lyfiApi!.getSunCurve(device);
            findProperty('sunCurve')?.value.notifyOfExternalUpdate(sunCurve);
            findProperty('sunColor')?.value.notifyOfExternalUpdate(lyfiStatus.sunColor);
          }
          break;
      }

      // Moon properties sync
      final moonConfig = await lyfiApi!.getMoonConfig(device);
      final moonSchedule = await lyfiApi!.getMoonSchedule(device);
      final moonCurve = await lyfiApi!.getMoonCurve(device);
      final moonStatus = await lyfiApi!.getMoonStatus(device);

      findProperty('moonConfig')?.value.notifyOfExternalUpdate(moonConfig);
      findProperty('moonSchedule')?.value.notifyOfExternalUpdate(moonSchedule);
      findProperty('moonCurve')?.value.notifyOfExternalUpdate(moonCurve);
      findProperty('moonStatus')?.value.notifyOfExternalUpdate(moonStatus);
    } catch (e, stackTrace) {
      logger?.w('Low-frequency sync failed: $e', error: e, stackTrace: stackTrace);
    }
  }

  // Track disposal and timer
  bool _disposed = false;
  bool get isDisposed => _disposed;
  Timer? _syncTimer;
  Timer? _lowFrequencySyncTimer;

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _lowFrequencySyncTimer?.cancel();

    super.dispose();
  }
}
