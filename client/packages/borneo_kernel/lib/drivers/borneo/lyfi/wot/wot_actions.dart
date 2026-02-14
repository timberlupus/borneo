// dart format width=120

import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:lw_wot/wot.dart';

/// Custom action for switching Lyfi states
class LyfiSwitchStateAction extends WotAction<Map<String, dynamic>> {
  final LyfiState targetState;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSwitchStateAction({
    required super.id,
    required super.thing,
    required this.targetState,
    required this.lyfiApi,
    required this.device,
  }) : super(name: 'switchState', input: {'state': targetState.name});

  @override
  Future<void> performAction() async {
    await lyfiApi.switchState(device, targetState);
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
  }) : super(name: 'switchMode', input: {'mode': targetMode.name, 'color': ?color});

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
    thing.findProperty('color')!.value.notifyOfExternalUpdate(color);
  }
}

/// Custom action for setting LED schedule
class LyfiSetScheduleAction extends WotAction<Map<String, dynamic>> {
  final ScheduleTable schedule;
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
    thing.findProperty('schedule')!.value.notifyOfExternalUpdate(schedule);
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
    thing.findProperty('acclimation')?.value.notifyOfExternalUpdate(settings);
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

/// Custom action for setting power behavior
class LyfiSetPowerBehaviorAction extends WotAction<Map<String, dynamic>> {
  final PowerBehavior behavior;
  final IBorneoDeviceApi borneoApi;
  final Device device;

  LyfiSetPowerBehaviorAction({
    required super.id,
    required super.thing,
    required this.behavior,
    required this.borneoApi,
    required this.device,
  }) : super(name: 'setPowerBehavior', input: {'behavior': behavior.name});

  @override
  Future<void> performAction() async {
    await borneoApi.setPowerBehavior(device, behavior);
  }
}

/// Custom action for setting moon configuration
class LyfiSetMoonConfigAction extends WotAction<Map<String, dynamic>> {
  final MoonConfig config;
  final ILyfiDeviceApi lyfiApi;
  final Device device;

  LyfiSetMoonConfigAction({
    required super.id,
    required super.thing,
    required this.config,
    required this.lyfiApi,
    required this.device,
  }) : super(name: 'setMoonConfig', input: {'config': config.toPayload()});

  @override
  Future<void> performAction() async {
    await lyfiApi.setMoonConfig(device, config);
    final curve = await lyfiApi.getMoonCurve(device);
    thing.findProperty('moonCurve')!.value.notifyOfExternalUpdate(curve);
  }
}
