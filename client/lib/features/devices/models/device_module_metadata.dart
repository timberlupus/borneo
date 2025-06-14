import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:borneo_app/features/devices/view_models/base_device_view_model.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/widgets.dart';

import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';

/// The declaration metadata for a certain type of device.
abstract class DeviceModuleMetadata {
  final String id;
  final String name;
  final DriverDescriptor driverDescriptor;
  final Widget Function(BuildContext context) detailsViewBuilder;
  final BaseDeviceViewModel Function(BuildContext context, String deviceID) detailsViewModelBuilder;
  final Widget Function(BuildContext context, double iconSize, bool isOnline) deviceIconBuilder;
  final Widget Function(BuildContext context, double iconSize) primaryStateIconBuilder;
  final List<Widget> Function(BuildContext, AbstractDeviceSummaryViewModel) secondaryStatesBuilder;
  final AbstractDeviceSummaryViewModel Function(DeviceEntity, DeviceManager, EventBus) createSummaryVM;

  const DeviceModuleMetadata({
    required this.id,
    required this.name,
    required this.driverDescriptor,
    required this.detailsViewBuilder,
    required this.detailsViewModelBuilder,
    required this.deviceIconBuilder,
    required this.primaryStateIconBuilder,
    required this.secondaryStatesBuilder,
    required this.createSummaryVM,
  });
}
