// dart format width=120

import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_wot/wot.dart';

/// LyfiThing extends WotThing to provide a specialized Web Thing for Lyfi devices
/// following the Mozilla WebThing pattern. This class encapsulates all Lyfi-specific
/// properties, actions, and events in a clean, reusable component.
class LyfiThing extends WotThing {
  final Device device;
  final DeviceEventBus deviceEvents;
  final IBorneoDeviceApi borneoApi;
  final ILyfiDeviceApi lyfiApi;

  // Property references for easy access
  late final WotProperty<bool> onOffProperty;
  late final WotProperty<String> stateProperty;
  late final WotProperty<String> modeProperty;
  late final WotProperty<List<int>> colorProperty;
  late final WotProperty<int> temporaryDurationProperty;
  late final WotProperty<String> correctionMethodProperty;
  late final WotProperty<bool> timeZoneEnabledProperty;
  late final WotProperty<int> timeZoneOffsetProperty;

  // Optional properties (may be null)
  WotProperty<int>? temperatureProperty;
  WotProperty<bool>? isStandaloneProperty;
  WotProperty<double>? nominalPowerProperty;
  WotProperty<int>? channelCountProperty;
  WotProperty<Map<String, double>>? locationProperty;

  LyfiThing({
    required this.device,
    required this.deviceEvents,
    required this.borneoApi,
    required this.lyfiApi,
    required String title,
  }) : super(id: device.id, title: title, type: ["OnOffSwitch", "Light"], description: "Lyfi LED lighting device");

  /// Initialize the LyfiThing with all properties and event subscriptions
  Future<void> initialize() async {
    final borneoDeviceInfo = borneoApi.getGeneralDeviceInfo(device);
    final lyfiDeviceInfo = lyfiApi.getLyfiInfo(device);

    final generalStatus = await borneoApi.getGeneralDeviceStatus(device);
    final lyfiStatus = await lyfiApi.getLyfiStatus(device);

    await _createProperties(generalStatus, lyfiStatus, borneoDeviceInfo, lyfiDeviceInfo);
    await _createActions();
    await _createEvents();
    _setupEventSubscriptions();
  }

  /// Create all device properties
  Future<void> _createProperties(
    GeneralBorneoDeviceStatus generalStatus,
    LyfiDeviceStatus lyfiStatus,
    GeneralBorneoDeviceInfo borneoDeviceInfo,
    LyfiDeviceInfo lyfiDeviceInfo,
  ) async {
    // Core on/off property
    onOffProperty = WotProperty<bool>(
      thing: this,
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
    addProperty(onOffProperty);

    // Lyfi state property
    stateProperty = WotProperty<String>(
      thing: this,
      name: 'state',
      value: WotValue<String>(
        initialValue: lyfiStatus.state.name,
        valueForwarder: (update) => lyfiApi.switchState(device, LyfiState.fromString(update)),
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

    // Lyfi mode property
    modeProperty = WotProperty<String>(
      thing: this,
      name: 'mode',
      value: WotValue<String>(
        initialValue: lyfiStatus.mode.name,
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

    // Temperature property (optional)
    if (generalStatus.temperature != null) {
      temperatureProperty = WotProperty<int>(
        thing: this,
        name: 'temperature',
        value: WotValue<int>(initialValue: generalStatus.temperature!),
        metadata: WotPropertyMetadata(
          type: 'integer',
          title: 'Temperature',
          description: 'Current device temperature',
          unit: '℃',
          readOnly: true,
        ),
      );
      addProperty(temperatureProperty!);
    }

    // Device info properties
    isStandaloneProperty = WotProperty<bool>(
      thing: this,
      name: 'isStandaloneController',
      value: WotValue<bool>(initialValue: lyfiDeviceInfo.isStandaloneController),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Is Standalone Controller',
        description: 'Whether device is a standalone controller',
        readOnly: true,
      ),
    );
    addProperty(isStandaloneProperty!);

    // Nominal power property (optional)
    if (lyfiDeviceInfo.nominalPower != null) {
      nominalPowerProperty = WotProperty<double>(
        thing: this,
        name: 'nominalPower',
        value: WotValue<double>(initialValue: lyfiDeviceInfo.nominalPower!),
        metadata: WotPropertyMetadata(
          type: 'number',
          title: 'Nominal Power',
          description: 'Nominal power consumption in Watts',
          unit: 'W',
          readOnly: true,
        ),
      );
      addProperty(nominalPowerProperty!);
    }

    // Channel count property
    channelCountProperty = WotProperty<int>(
      thing: this,
      name: 'channelCount',
      value: WotValue<int>(initialValue: lyfiDeviceInfo.channelCount),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Channel Count',
        description: 'Number of LED channels',
        readOnly: true,
      ),
    );
    addProperty(channelCountProperty!);

    // Color property for manual mode
    colorProperty = WotProperty<List<int>>(
      thing: this,
      name: 'color',
      value: WotValue<List<int>>(
        initialValue: await lyfiApi.getColor(device),
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

    // Temporary duration property
    final temporaryDuration = await lyfiApi.getTemporaryDuration(device);
    temporaryDurationProperty = WotProperty<int>(
      thing: this,
      name: 'temporaryDuration',
      value: WotValue<int>(
        initialValue: temporaryDuration.inMinutes,
        valueForwarder: (update) => lyfiApi.setTemporaryDuration(device, Duration(minutes: update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Temporary Duration',
        description: 'Duration for temporary mode in minutes',
        minimum: 1,
        maximum: 1440, // 24 hours
        readOnly: false,
      ),
    );
    addProperty(temporaryDurationProperty);

    // Correction method property
    final correctionMethod = await lyfiApi.getCorrectionMethod(device);
    correctionMethodProperty = WotProperty<String>(
      thing: this,
      name: 'correctionMethod',
      value: WotValue<String>(
        initialValue: correctionMethod.name,
        valueForwarder: (update) => lyfiApi.setCorrectionMethod(device, LedCorrectionMethod.values.byName(update)),
      ),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Correction Method',
        description: 'LED color correction method',
        enumValues: LedCorrectionMethod.values.map((e) => e.name).toList(),
        readOnly: false,
      ),
    );
    addProperty(correctionMethodProperty);

    // Location property (optional)
    final location = await lyfiApi.getLocation(device);
    if (location != null) {
      locationProperty = WotProperty<Map<String, double>>(
        thing: this,
        name: 'location',
        value: WotValue<Map<String, double>>(
          initialValue: {'latitude': location.lat, 'longitude': location.lng},
          valueForwarder: (update) =>
              lyfiApi.setLocation(device, GeoLocation(lat: update['latitude']!, lng: update['longitude']!)),
        ),
        metadata: WotPropertyMetadata(
          type: 'object',
          title: 'Location',
          description: 'Geographic location coordinates',
          readOnly: false,
        ),
      );
      addProperty(locationProperty!);
    }

    // Timezone properties
    final timeZoneEnabled = await lyfiApi.getTimeZoneEnabled(device);
    timeZoneEnabledProperty = WotProperty<bool>(
      thing: this,
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
    addProperty(timeZoneEnabledProperty);

    final timeZoneOffset = await lyfiApi.getTimeZoneOffset(device);
    timeZoneOffsetProperty = WotProperty<int>(
      thing: this,
      name: 'timeZoneOffset',
      value: WotValue<int>(
        initialValue: timeZoneOffset,
        valueForwarder: (update) => lyfiApi.setTimeZoneOffset(device, update),
      ),
      metadata: WotPropertyMetadata(
        type: 'integer',
        title: 'Time Zone Offset',
        description: 'Timezone offset in seconds',
        minimum: -43200, // -12 hours
        maximum: 50400, // +14 hours
        readOnly: false,
      ),
    );
    addProperty(timeZoneOffsetProperty);
  }

  /// Create device actions
  Future<void> _createActions() async {
    // Switch to sun mode action
    addAvailableAction(
      'switchToSunMode',
      WotActionMetadata(title: 'Switch to Sun Mode', description: 'Switch the device to sun lighting mode'),
      (thing, input) => LyfiSwitchModeAction(
        id: 'switch-sun-${DateTime.now().millisecondsSinceEpoch}',
        thing: thing,
        targetMode: LyfiMode.sun,
        lyfiApi: lyfiApi,
        device: device,
      ),
    );

    // Switch to manual mode action
    addAvailableAction(
      'switchToManualMode',
      WotActionMetadata(
        title: 'Switch to Manual Mode',
        description: 'Switch the device to manual lighting mode',
        input: {
          'type': 'object',
          'properties': {
            'color': {
              'type': 'array',
              'items': {'type': 'integer', 'minimum': 0, 'maximum': 100},
              'description': 'Optional color values for each channel',
            },
          },
        },
      ),
      (thing, input) => LyfiSwitchModeAction(
        id: 'switch-manual-${DateTime.now().millisecondsSinceEpoch}',
        thing: thing,
        targetMode: LyfiMode.manual,
        lyfiApi: lyfiApi,
        device: device,
        color: input?['color'],
      ),
    );

    // Set color action
    addAvailableAction(
      'setColor',
      WotActionMetadata(
        title: 'Set Color',
        description: 'Set the LED channel brightness values',
        input: {
          'type': 'object',
          'required': ['color'],
          'properties': {
            'color': {
              'type': 'array',
              'items': {'type': 'integer', 'minimum': 0, 'maximum': 100},
              'description': 'Brightness values for each LED channel',
            },
          },
        },
      ),
      (thing, input) => LyfiSetColorAction(
        id: 'set-color-${DateTime.now().millisecondsSinceEpoch}',
        thing: thing,
        color: List<int>.from(input['color']),
        lyfiApi: lyfiApi,
        device: device,
      ),
    );
  }

  /// Create device events
  Future<void> _createEvents() async {
    // State changed event
    addAvailableEvent(
      'stateChanged',
      WotEventMetadata(type: 'string', title: 'State Changed', description: 'Fired when the device state changes'),
    );

    // Mode changed event
    addAvailableEvent(
      'modeChanged',
      WotEventMetadata(type: 'string', title: 'Mode Changed', description: 'Fired when the lighting mode changes'),
    );

    // Power changed event
    addAvailableEvent(
      'powerChanged',
      WotEventMetadata(type: 'boolean', title: 'Power Changed', description: 'Fired when the power state changes'),
    );

    // Color changed event
    addAvailableEvent(
      'colorChanged',
      WotEventMetadata(type: 'array', title: 'Color Changed', description: 'Fired when the LED color values change'),
    );

    // Temperature changed event (if temperature sensor available)
    if (temperatureProperty != null) {
      addAvailableEvent(
        'temperatureChanged',
        WotEventMetadata(
          type: 'integer',
          title: 'Temperature Changed',
          description: 'Fired when the device temperature changes',
        ),
      );
    }
  }

  /// Set up event subscriptions to device events
  void _setupEventSubscriptions() {
    // TODO: Set up event subscriptions to update properties when device events occur
    // This would typically involve listening to DeviceEventBus events and updating
    // properties accordingly, then firing WoT events

    // Example structure (implement based on your event system):
    // deviceEvents.on<LyfiStateChangedEvent>().listen((event) {
    //   stateProperty.value.notifyOfExternalUpdate(event.state.name);
    //   addEvent(WotEvent(thing: this, name: 'stateChanged', data: event.state.name));
    // });

    // deviceEvents.on<LyfiModeChangedEvent>().listen((event) {
    //   modeProperty.value.notifyOfExternalUpdate(event.mode.name);
    //   addEvent(WotEvent(thing: this, name: 'modeChanged', data: event.mode.name));
    // });

    // deviceEvents.on<DevicePowerOnOffChangedEvent>().listen((event) {
    //   onOffProperty.value.notifyOfExternalUpdate(event.onOff);
    //   addEvent(WotEvent(thing: this, name: 'powerChanged', data: event.onOff));
    // });
  }

  // Convenience methods for common operations

  /// Get the current brightness as a percentage (0-100)
  double get brightness {
    final color = colorProperty.getValue();
    if (color.isEmpty) return 0.0;
    return color.fold(0, (sum, value) => sum + value) / color.length;
  }

  /// Set brightness while maintaining color ratios
  Future<void> setBrightness(double percentage) async {
    percentage = percentage.clamp(0.0, 100.0);
    final currentColor = colorProperty.getValue();

    if (currentColor.isEmpty) return;

    // Calculate the scaling factor
    final currentMax = currentColor.reduce((a, b) => a > b ? a : b);
    if (currentMax == 0) {
      // All channels are off, set them all to the same value
      final newColor = List.filled(currentColor.length, percentage.round());
      colorProperty.setValue(newColor);
    } else {
      // Scale all channels proportionally
      final scaleFactor = percentage / currentMax;
      final newColor = currentColor.map((value) => (value * scaleFactor).round().clamp(0, 100)).toList();
      colorProperty.setValue(newColor);
    }
  }

  /// Check if the device is currently on
  bool get isOn => onOffProperty.getValue();

  /// Get the current state
  LyfiState get currentState => LyfiState.values.byName(stateProperty.getValue());

  /// Get the current mode
  LyfiMode get currentMode => LyfiMode.values.byName(modeProperty.getValue());

  /// Check if device supports location features
  bool get hasLocation => locationProperty != null;

  /// Check if device has temperature sensor
  bool get hasTemperatureSensor => temperatureProperty != null;
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
