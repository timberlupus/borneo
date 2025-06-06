import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/lyfi_view.dart';
import 'package:borneo_app/models/devices/device_module_metadata.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/i_app_notification_service.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'package:provider/provider.dart';

import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class LyfiDeviceModuleMetadata extends DeviceModuleMetadata {
  LyfiDeviceModuleMetadata()
    : super(
        id: kLyfiDriverID,
        name: kLyfiDriverName,
        driverDescriptor: borneoLyfiDriverDescriptor,
        detailsViewBuilder: (_) => LyfiView(),
        detailsViewModelBuilder:
            (context, deviceID) => LyfiViewModel(
              deviceID: deviceID,
              deviceManager: context.read<DeviceManager>(),
              globalEventBus: context.read<EventBus>(),
              notification: context.read<IAppNotificationService>(),
              logger: context.read<Logger>(),
            ),
        deviceIconBuilder: _buildDeviceIcon,
        primaryStateIconBuilder: _buildPrimaryStateIcon,
        secondaryStatesBuilder: _secondaryStatesBuilder,
      );

  static Widget _buildDeviceIcon(BuildContext context, double iconSize, bool isOnline) {
    return Icon(
      Icons.lightbulb_outline,
      size: iconSize,
      color:
          isOnline
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.38),
    );
  }

  static Widget _buildPrimaryStateIcon(BuildContext context, double iconSize) {
    return Icon(Icons.light_mode_outlined, size: iconSize, color: Theme.of(context).colorScheme.onSurface);
  }

  static String _modeText(BuildContext context, LedRunningMode? mode) {
    switch (mode) {
      case LedRunningMode.manual:
        return context.translate('Manual');
      case LedRunningMode.scheduled:
        return context.translate('Scheduled');
      case LedRunningMode.sun:
        return context.translate('Sun');
      default:
        return '-';
    }
  }

  static String _stateText(BuildContext context, LedState? state) {
    switch (state) {
      case LedState.normal:
        return context.translate('Normal');
      case LedState.dimming:
        return context.translate('Dimming');
      case LedState.temporary:
        return context.translate('Temporary');
      case LedState.preview:
        return context.translate('Preview');
      default:
        return '-';
    }
  }

  static List<Widget> _secondaryStatesBuilder(BuildContext context, BoundDevice bound, EventBus deviceEventBus) {
    final lyfiApi = bound.api<ILyfiDeviceApi>();

    // Mode widget: FutureBuilder for initial, StreamBuilder for updates
    final modeWidget = FutureBuilder<LedRunningMode>(
      future: lyfiApi.getMode(bound.device),
      builder: (context, modeSnapshot) {
        return StreamBuilder<LyfiModeChangedEvent>(
          stream: deviceEventBus.on<LyfiModeChangedEvent>(),
          builder: (context, streamSnapshot) {
            final mode = streamSnapshot.data?.mode ?? modeSnapshot.data;
            return Text(_modeText(context, mode), style: Theme.of(context).textTheme.labelSmall);
          },
        );
      },
    );

    // State widget: FutureBuilder for initial, StreamBuilder for updates
    final stateWidget = FutureBuilder<LedState>(
      future: lyfiApi.getState(bound.device),
      builder: (context, stateSnapshot) {
        return StreamBuilder<LyfiStateChangedEvent>(
          stream: deviceEventBus.on<LyfiStateChangedEvent>(),
          builder: (context, streamSnapshot) {
            final state = streamSnapshot.data?.state ?? stateSnapshot.data;
            return Text(_stateText(context, state), style: Theme.of(context).textTheme.labelSmall);
          },
        );
      },
    );

    return [stateWidget, modeWidget];
  }
}
