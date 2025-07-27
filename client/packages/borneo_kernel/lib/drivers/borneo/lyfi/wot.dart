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

/// Custom WotProperty for state that handles its own event subscription
class LyfiStateProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiStateProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiStateChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.state.name);
      thing.addEvent(WotEvent(thing: thing, name: 'stateChanged', data: event.state.name));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for mode that handles its own event subscription
class LyfiModeProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiModeProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiModeChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.mode.name);
      thing.addEvent(WotEvent(thing: thing, name: 'modeChanged', data: event.mode.name));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for power on/off that handles its own event subscription
class LyfiPowerProperty extends WotProperty<bool> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiPowerProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<DevicePowerOnOffChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.onOff);
      thing.addEvent(WotEvent(thing: thing, name: 'powerChanged', data: event.onOff));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom action for switching Lyfi modes
class LyfiSwitchModeAction extends WotAction<Map<String, dynamic>?> {
  final LyfiMode targetMode;
  final ILyfiDeviceApi lyfiApi;
  final Device device;
  final List<int>? color;

  LyfiSwitchModeAction({
    required super.id,
    required super.thing,
    required this.targetMode,
    required this.lyfiApi,
    required this.device,
    this.color,
  }) : super(name: 'switchMode', input: {'mode': targetMode.name, if (color != null) 'color': color});

  @override
  Future<void> performAction() async {
    await lyfiApi.switchMode(device, targetMode);
    if (color != null && targetMode == LyfiMode.manual) {
      await lyfiApi.setColor(device, color!);
    }
  }
}

/// Custom action for setting LED colors
class LyfiSetColorAction extends WotAction<Map<String, dynamic>> {
  final List<int> color;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSetColorAction({
    required super.id,
    required super.thing,
    required this.color,
    required this.lyfiApi,
    required this.device,
  }) : super(name: 'setColor', input: {'color': color});

  @override
  Future<void> performAction() async {
    await lyfiApi.setColor(device, color);
  }
}

/// Custom action for setting LED schedule
class LyfiSetScheduleAction extends WotAction<Map<String, dynamic>> {
  final List<ScheduledInstant> schedule;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSetScheduleAction({
    required super.id,
    required super.thing,
    required this.schedule,
    required this.lyfiApi,
    required this.device,
  }) : super(name: 'setSchedule', input: {'schedule': schedule.map((s) => s.toPayload()).toList()});

  @override
  Future<void> performAction() async {
    await lyfiApi.setSchedule(device, schedule);
  }
}

/// Custom action for setting acclimation settings
class LyfiSetAcclimationAction extends WotAction<Map<String, dynamic>> {
  final AcclimationSettings settings;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSetAcclimationAction({
    required super.id,
    required super.thing,
    required this.settings,
    required this.lyfiApi,
    required this.device,
  }) : super(
         name: 'setAcclimation',
         input: {
           'enabled': settings.enabled,
           'startTimestamp': (settings.startTimestamp.millisecondsSinceEpoch / 1000).round(),
           'startPercent': settings.startPercent,
           'days': settings.days,
         },
       );

  @override
  Future<void> performAction() async {
    await lyfiApi.setAcclimation(device, settings);
  }
}

/// Custom action for setting geographic location
class LyfiSetLocationAction extends WotAction<Map<String, dynamic>> {
  final GeoLocation location;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSetLocationAction({
    required super.id,
    required super.thing,
    required this.location,
    required this.lyfiApi,
    required this.device,
  }) : super(name: 'setLocation', input: {'lat': location.lat, 'lng': location.lng});

  @override
  Future<void> performAction() async {
    await lyfiApi.setLocation(device, location);
  }
}

/// Custom action for setting LED correction method
class LyfiSetCorrectionMethodAction extends WotAction<Map<String, dynamic>> {
  final LedCorrectionMethod method;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSetCorrectionMethodAction({
    required super.id,
    required super.thing,
    required this.method,
    required this.lyfiApi,
    required this.device,
  }) : super(name: 'setCorrectionMethod', input: {'method': method.name});

  @override
  Future<void> performAction() async {
    await lyfiApi.setCorrectionMethod(device, method);
  }
}

/// Custom WotProperty for schedule that handles its own event subscription
class LyfiScheduleProperty extends WotProperty<List<ScheduledInstant>> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiScheduleProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiScheduleChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.schedule);
      thing.addEvent(WotEvent(thing: thing, name: 'scheduleChanged', data: event.schedule));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for acclimation settings that handles its own event subscription
class LyfiAcclimationProperty extends WotProperty<AcclimationSettings> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiAcclimationProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiAcclimationChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.settings);
      thing.addEvent(WotEvent(thing: thing, name: 'acclimationChanged', data: event.settings));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for location that handles its own event subscription
class LyfiLocationProperty extends WotProperty<GeoLocation?> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiLocationProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiLocationChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.location);
      thing.addEvent(WotEvent(thing: thing, name: 'locationChanged', data: event.location));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for correction method that handles its own event subscription
class LyfiCorrectionMethodProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiCorrectionMethodProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiCorrectionMethodChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.method.name);
      thing.addEvent(WotEvent(thing: thing, name: 'correctionMethodChanged', data: event.method.name));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// LyfiThing extends WotThing following Mozilla WebThing initialization pattern
/// This class uses default values during construction and binds to actual hardware asynchronously
class LyfiThing extends WotThing {
  final Logger? logger;
  final Device device;
  final DeviceEventBus deviceEvents;
  final IBorneoDeviceApi borneoApi;
  final ILyfiDeviceApi lyfiApi;

  // Property references
  late final LyfiPowerProperty onOffProperty;
  late final LyfiStateProperty stateProperty;
  late final LyfiModeProperty modeProperty;
  late final WotProperty<List<int>> colorProperty;
  late final LyfiScheduleProperty scheduleProperty;
  late final LyfiAcclimationProperty acclimationProperty;
  late final LyfiLocationProperty locationProperty;
  late final LyfiCorrectionMethodProperty correctionMethodProperty;
  late final WotProperty<bool> timeZoneEnabledProperty;
  late final WotProperty<int> timeZoneOffsetProperty;
  late final WotProperty<int> keepTempProperty;

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
    _setupEventSubscriptions();
    _setupPeriodicSync();
  }

  /// Create properties with reasonable defaults first, then bind to hardware
  /// This follows Mozilla WebThing pattern of creating Value objects with initial values
  Future<void> _createPropertiesWithDefaults() async {
    // Power property with default false, will be updated when hardware is ready
    onOffProperty = LyfiPowerProperty(
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
    );
    addProperty(onOffProperty);

    // State property with default state
    stateProperty = LyfiStateProperty(
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
    );
    addProperty(stateProperty);

    // Mode property with default mode
    modeProperty = LyfiModeProperty(
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
    scheduleProperty = LyfiScheduleProperty(
      thing: this,
      deviceEvents: deviceEvents,
      name: 'schedule',
      value: WotValue<List<ScheduledInstant>>(
        initialValue: [], // Default empty schedule
        valueForwarder: (update) => lyfiApi.setSchedule(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'array',
        title: 'Schedule',
        description: 'LED lighting schedule with time instants and colors',
        readOnly: false,
      ),
    );
    addProperty(scheduleProperty);

    // Acclimation property
    acclimationProperty = LyfiAcclimationProperty(
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
    );
    addProperty(acclimationProperty);

    // Location property
    locationProperty = LyfiLocationProperty(
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
    );
    addProperty(locationProperty);

    // Correction method property
    correctionMethodProperty = LyfiCorrectionMethodProperty(
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

      logger?.d('LyfiThing: Successfully bound to hardware state');
    } catch (e, stackTrace) {
      // Continue with default values if hardware is not available
      logger?.e('LyfiThing: Warning - Failed to bind to hardware: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Set up event subscriptions (like Mozilla WebThing GPIO change events)
  void _setupEventSubscriptions() {
    onOffProperty.subscribeToEvents();
    stateProperty.subscribeToEvents();
    modeProperty.subscribeToEvents();
    scheduleProperty.subscribeToEvents();
    acclimationProperty.subscribeToEvents();
    locationProperty.subscribeToEvents();
    correctionMethodProperty.subscribeToEvents();
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

      // Only update if different (like Mozilla WebThing value comparison)
      if (onOffProperty.getValue() != generalStatus.power) {
        onOffProperty.value.notifyOfExternalUpdate(generalStatus.power);
      }
    } catch (e) {
      // Silent fail for background sync
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

    onOffProperty.unsubscribeFromEvents();
    stateProperty.unsubscribeFromEvents();
    modeProperty.unsubscribeFromEvents();
    scheduleProperty.unsubscribeFromEvents();
    acclimationProperty.unsubscribeFromEvents();
    locationProperty.unsubscribeFromEvents();
    correctionMethodProperty.unsubscribeFromEvents();

    super.dispose();
  }
}
