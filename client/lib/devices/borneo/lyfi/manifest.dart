import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/lyfi_view.dart';
import 'package:borneo_app/models/devices/device_module_metadata.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/i_app_notification_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'package:provider/provider.dart';

import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';

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
}
