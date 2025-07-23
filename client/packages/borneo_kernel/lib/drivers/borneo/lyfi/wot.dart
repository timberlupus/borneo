// dart format width=120

import 'dart:async';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:lw_wot/wot.dart';

/// Custom WotProperty for state that handles its own event subscription
class LyfiStateProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;
  final WotThing thing;

  LyfiStateProperty({
    required this.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  }) : super(thing: thing);

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
  final WotThing thing;

  LyfiPowerProperty({
    required this.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  }) : super(thing: thing);

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

/// LyfiThing extends WotThing following Mozilla WebThing initialization pattern
/// This class uses default values during construction and binds to actual hardware asynchronously
class LyfiThing extends WotThing {
  final Device device;
  final DeviceEventBus deviceEvents;
  final IBorneoDeviceApi borneoApi;
  final ILyfiDeviceApi lyfiApi;

  // Property references
  late final LyfiPowerProperty onOffProperty;
  late final LyfiStateProperty stateProperty;
  late final LyfiModeProperty modeProperty;
  late final WotProperty<List<int>> colorProperty;

  LyfiThing({
    required this.device,
    required this.deviceEvents,
    required this.borneoApi,
    required this.lyfiApi,
    required super.title,
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
  }

  /// Bind properties to actual hardware state (like Mozilla WebThing ready callback)
  Future<void> _bindToHardware() async {
    try {
      // Get actual device state and update property values
      final generalStatus = await borneoApi.getGeneralDeviceStatus(device);
      final lyfiStatus = await lyfiApi.getLyfiStatus(device);
      final actualColor = await lyfiApi.getColor(device);

      // Update properties with actual values (like notifyOfExternalUpdate in Mozilla WebThing)
      onOffProperty.value.notifyOfExternalUpdate(generalStatus.power);
      stateProperty.value.notifyOfExternalUpdate(lyfiStatus.state.name);
      modeProperty.value.notifyOfExternalUpdate(lyfiStatus.mode.name);
      colorProperty.value.notifyOfExternalUpdate(actualColor);

      print('LyfiThing: Successfully bound to hardware state');
    } catch (e) {
      print('LyfiThing: Warning - Failed to bind to hardware: $e');
      // Continue with default values if hardware is not available
    }
  }

  /// Set up event subscriptions (like Mozilla WebThing GPIO change events)
  void _setupEventSubscriptions() {
    onOffProperty.subscribeToEvents();
    stateProperty.subscribeToEvents();
    modeProperty.subscribeToEvents();
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

    super.dispose();
  }
}
