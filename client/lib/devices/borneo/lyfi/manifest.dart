import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/summary_device_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/lyfi_view.dart';
import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:borneo_app/core/services/i_app_notification_service.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'package:provider/provider.dart';

import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class LyfiDeviceModuleMetadata extends DeviceModuleMetadata {
  LyfiDeviceModuleMetadata()
    : super(
        id: kLyfiDriverID,
        name: kLyfiDriverName,
        driverDescriptor: borneoLyfiDriverDescriptor,
        detailsViewBuilder: (_) => LyfiView(),
        detailsViewModelBuilder: (context, deviceID) => LyfiViewModel(
          deviceID: deviceID,
          deviceManager: context.read<DeviceManager>(),
          globalEventBus: context.read<EventBus>(),
          notification: context.read<IAppNotificationService>(),
          logger: context.read<Logger>(),
        ),
        deviceIconBuilder: _buildDeviceIcon,
        primaryStateIconBuilder: _buildPrimaryStateIcon,
        secondaryStatesBuilder: _secondaryStatesBuilder,
        createSummaryVM: (dev, dm, bus) => LyfiSummaryDeviceViewModel(dev, dm, bus),
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
    final modeWidget = Text(_modeText(context, lvm.ledMode), style: Theme.of(context).textTheme.labelSmall);
    final stateWidget = Text(_stateText(context, lvm.ledState), style: Theme.of(context).textTheme.labelSmall);
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
}
