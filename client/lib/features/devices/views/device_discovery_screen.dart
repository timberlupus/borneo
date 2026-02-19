import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/features/devices/models/discoverable_device.dart';
import 'package:borneo_app/features/devices/views/device_group_selection_sheet.dart';
import 'package:borneo_app/features/devices/views/wifi_selection_screen.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/services/devices/device_manager.dart';
import '../../../core/services/devices/ble_provisioner.dart';
import '../view_models/device_discovery_view_model.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

class DeviceDiscoveryScreen extends StatelessWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gt = GettextLocalizations.of(context);
    return ChangeNotifierProvider(
      create: (cb) => DeviceDiscoveryViewModel(
        cb.read<Logger>(),
        cb.read<IGroupManager>(),
        cb.read<IDeviceManager>(),
        cb.read<IBleProvisioner>(),
        cb.read<IDeviceModuleRegistry>(),
        globalEventBus: cb.read<EventBus>(),
        gt: gt,
        logger: cb.read<Logger>(),
      )..initialize(),
      child: const _DeviceDiscoveryContent(),
    );
  }
}

class _DeviceDiscoveryContent extends StatelessWidget {
  const _DeviceDiscoveryContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.read<DeviceDiscoveryViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.translate('Add Device')),
        actions: [
          Selector<DeviceDiscoveryViewModel, bool>(
            selector: (_, vm) => vm.isDiscovering,
            builder: (ctx, isDiscovering, child) {
              if (isDiscovering) {
                return const SizedBox();
              } else {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ctx.read<DeviceDiscoveryViewModel>().startDiscovery(),
                  tooltip: context.translate('Refresh'),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!vm.isMobile)
            Container(
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: EdgeInsets.all(8),
              width: double.infinity,
              child: Text(
                context.translate('Device provisioning is only available on iOS and Android.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
              ),
            ),
          ValueListenableBuilder<String?>(
            valueListenable: vm.scanError,
            builder: (context, error, child) {
              if (error == null) return const SizedBox();
              return Container(
                color: Theme.of(context).colorScheme.errorContainer,
                padding: EdgeInsets.all(12),
                width: double.infinity,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        error,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                    IconButton(
                      onPressed: () => vm.scanError.value = null,
                      icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error, size: 20),
                      tooltip: context.translate('Close'),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Selector<DeviceDiscoveryViewModel, (bool, List<DiscoverableDevice>)>(
              selector: (_, vm) => (vm.isDiscovering, vm.discoverableDevices.value),
              builder: (context, state, child) {
                final (isDiscovering, devices) = state;

                return Stack(
                  children: [
                    if (devices.isEmpty && vm.isInitialized && !vm.isDiscovering && !vm.isBusy && !vm.isDisposed)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.media_bluetooth_off,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.38),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.translate('No devices found'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => context.read<DeviceDiscoveryViewModel>().startDiscovery(),
                                    icon: const Icon(Icons.refresh),
                                    label: Text(context.translate('Scan')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        itemCount: devices.length,
                        separatorBuilder: (context, index) => Divider(height: 1),
                        itemBuilder: (context, index) {
                          final vm = context.read<DeviceDiscoveryViewModel>();
                          return _buildDeviceTile(context, vm, devices[index]);
                        },
                      ),
                    if (isDiscovering)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.translate('Searching for devices...'),
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () => context.read<DeviceDiscoveryViewModel>().stopDiscovery(),
                                    child: Text(context.translate('Cancel')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, DeviceDiscoveryViewModel vm, DiscoverableDevice device) {
    if (device.type == DiscoverableDeviceType.provisioned && device.provisionedData != null) {
      return _buildProvisionedTile(context, vm, device.provisionedData!);
    } else {
      return _buildUnprovisionedTile(context, vm, device.name);
    }
  }

  Widget _buildProvisionedTile(
    BuildContext context,
    DeviceDiscoveryViewModel vm,
    SupportedDeviceDescriptor deviceDesc,
  ) {
    return ListTile(
      leading: _buildDeviceIcon(context, vm, deviceDesc),
      title: Text(deviceDesc.name),
      subtitle: Text(context.translate('Detected on network')),
      trailing: const Icon(Icons.add),
      onTap: () => _showAddDeviceSheet(context, vm, deviceDesc),
    );
  }

  Widget _buildUnprovisionedTile(BuildContext context, DeviceDiscoveryViewModel vm, String name) {
    return ListTile(
      leading: Container(
        height: 48,
        width: 48,
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
            side: BorderSide(width: 1.5, color: Theme.of(context).colorScheme.tertiaryContainer),
          ),
        ),
        child: Icon(Icons.bluetooth, size: 32, color: Theme.of(context).colorScheme.onTertiaryContainer),
      ),
      title: Text(name),
      subtitle: Text(context.translate('Ready to provision')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        if (vm.isMobile) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WifiSelectionScreen(deviceName: name)),
          );
          // Check if we need to refresh after provisioning
          if (result != null && result is Map && result['refresh'] == true) {
            vm.startDiscovery();
          }
        }
      },
    );
  }

  Widget _buildDeviceIcon(BuildContext context, DeviceDiscoveryViewModel vm, SupportedDeviceDescriptor deviceDesc) {
    final meta = vm.deviceMdoules.metaModules.containsKey(deviceDesc.driverDescriptor.id)
        ? vm.deviceMdoules.metaModules[deviceDesc.driverDescriptor.id]
        : null;
    Widget iconWidget;
    if (meta != null) {
      iconWidget = meta.deviceIconBuilder(context, 40, true);
    } else {
      iconWidget = Icon(Icons.device_unknown, size: 40, color: Theme.of(context).colorScheme.outline);
    }

    return Container(
      height: 48,
      width: 48,
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.0),
          side: BorderSide(width: 1.5, color: Theme.of(context).colorScheme.primaryContainer),
        ),
      ),
      child: Center(child: iconWidget),
    );
  }

  void _showAddDeviceSheet(BuildContext context, DeviceDiscoveryViewModel vm, SupportedDeviceDescriptor deviceInfo) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => DeviceGroupSelectionSheet(
        availableGroups: vm.availableGroups,
        onTapGroup: (g) {
          vm.addNewDevice(deviceInfo, g);
          Navigator.pop(context); // Close sheet
          // Optionally close screen or show snackbar.
          // Existing logic had a snackbar listener.
          context.read<IAppNotificationService>().showSuccess(context.translate('Device Added'));
        },
        title: 'Registry "${deviceInfo.name}"',
        subtitle: context.translate('Select the group to which the new device belongs:'),
      ),
    );
  }
}
