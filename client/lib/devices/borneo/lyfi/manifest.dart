import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/summary_device_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/lyfi_view.dart';
import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext.dart';
import 'package:logger/logger.dart';
import 'package:lw_wot/wot.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';

import 'package:provider/provider.dart';

import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';

class LyfiDeviceModuleMetadata extends DeviceModuleMetadata {
  LyfiDeviceModuleMetadata()
    : super(
        id: kLyfiDriverID,
        name: kLyfiDriverName,
        driverDescriptor: borneoLyfiDriverDescriptor,
        detailsViewBuilder: (_) => LyfiView(),
        detailsViewModelBuilder: (context, deviceID) => LyfiViewModel(
          deviceManager: context.read<IDeviceManager>(),
          globalEventBus: context.read<EventBus>(),
          notification: context.read<IAppNotificationService>(),
          wotThing: context.read<IDeviceManager>().getWotThing(deviceID),
          localeService: context.read<ILocaleService>(),
          gt: GettextLocalizations.of(context),
          logger: context.read<Logger>(),
        ),
        deviceIconBuilder: _buildDeviceIcon,
        primaryStateIconBuilder: _buildPrimaryStateIcon,
        secondaryStatesBuilder: _secondaryStatesBuilder,
        createSummaryVM: (dev, dm, bus, gt) => LyfiSummaryDeviceViewModel(dev, dm, bus, gt: gt),
        createWotThing: _createWotThing,
      );

  static Widget _buildDeviceIcon(BuildContext context, double iconSize, bool isOnline) {
    return Icon(
      Icons.light_outlined,
      size: iconSize,
      color: isOnline
          ? Theme.of(context).colorScheme.onPrimaryContainer
          : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.38),
    );
  }

  static Widget _buildPrimaryStateIcon(BuildContext context, double iconSize) {
    return Icon(Icons.light_mode_outlined, size: iconSize, color: Theme.of(context).colorScheme.onSurface);
  }

  static List<Widget> _secondaryStatesBuilder(BuildContext context, AbstractDeviceSummaryViewModel vm) {
    final lvm = vm as LyfiSummaryDeviceViewModel;
    final modeWidget = ValueListenableBuilder<LyfiMode?>(
      valueListenable: lvm.ledMode,
      builder: (context, mode, child) => Text(_modeText(context, mode), style: Theme.of(context).textTheme.labelSmall),
    );
    final stateWidget = ValueListenableBuilder<LyfiState?>(
      valueListenable: lvm.ledState,
      builder: (context, state, child) =>
          Text(_stateText(context, state), style: Theme.of(context).textTheme.labelSmall),
    );
    return [modeWidget, stateWidget];
  }

  static String _modeText(BuildContext context, LyfiMode? mode) {
    switch (mode) {
      case LyfiMode.manual:
        return context.translate('Manual');
      case LyfiMode.scheduled:
        return context.translate('Scheduled');
      case LyfiMode.sun:
        return context.translate('Sun Simulation');
      default:
        return '-';
    }
  }

  static String _stateText(BuildContext context, LyfiState? state) {
    switch (state) {
      case LyfiState.normal:
        return context.translate('Running');
      case LyfiState.dimming:
        return context.translate('Dimming');
      case LyfiState.temporary:
        return context.translate('Temporary');
      case LyfiState.preview:
        return context.translate('Preview');
      default:
        return '-';
    }
  }

  static Future<WotThing> _createWotThing(DeviceEntity device, IDeviceManager deviceManager, {Logger? logger}) async {
    try {
      // Get the bound device and extract APIs
      final boundDevice = deviceManager.getBoundDevice(device.id);
      final borneoApi = boundDevice.api<IBorneoDeviceApi>();
      final lyfiApi = boundDevice.api<ILyfiDeviceApi>();
      final deviceEvents = boundDevice.device.driverData.deviceEvents;

      // Create the real LyfiThing with API connections
      final lyfiThing = LyfiThing(
        device: boundDevice.device,
        deviceEvents: deviceEvents,
        borneoApi: borneoApi,
        lyfiApi: lyfiApi,
        title: device.name,
        logger: logger,
        canWrite: () => deviceManager.isBound(device.id),
      );

      // Initialize the LyfiThing asynchronously (hardware binding)
      // Note: This doesn't block creation, initialization happens in background
      await lyfiThing.initialize();
      return lyfiThing;
    } catch (e, st) {
      // If API access fails, fall back to basic WotThing
      logger?.w('Failed to create online device with APIs for ${device.id}: $e', error: e, stackTrace: st);

      // Create offline LyfiThing
      final deviceEvents = DeviceEventBus(); // TODO FIXME
      final lyfiThing = LyfiThing.offline(
        device: device,
        deviceEvents: deviceEvents,
        title: device.name,
        logger: logger,
        canWrite: () => false, // Offline, cannot write
      );
      await lyfiThing.initialize();
      return lyfiThing;
    }
  }
}
