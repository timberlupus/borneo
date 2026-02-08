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
    return ChangeNotifierProvider(
      create: (context) => DeviceDiscoveryViewModel(
        context.read<Logger>(),
        context.read<IGroupManager>(),
        context.read<IDeviceManager>(),
        context.read<IBleProvisioner>(),
        context.read<IDeviceModuleRegistry>(),
        globalEventBus: context.read<EventBus>(),
        gt: GettextLocalizations.of(context),
        logger: context.read<Logger>(),
      )..onInitialize(),
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
                return TextButton(
                  onPressed: () => ctx.read<DeviceDiscoveryViewModel>().stopDiscovery(),
                  child: Text(
                    context.translate('Stop'),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                );
              } else {
                return IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () => ctx.read<DeviceDiscoveryViewModel>().startDiscovery(),
                  tooltip: context.translate('Refresh'),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: vm.initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(context.translate('Searching for devices...'), style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (!vm.isMobile)
                Container(
                  color: Colors.amber.shade100,
                  padding: EdgeInsets.all(8),
                  width: double.infinity,
                  child: Text(
                    context.translate('Device provisioning is only available on iOS and Android.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ValueListenableBuilder<String?>(
                valueListenable: vm.scanError,
                builder: (context, error, child) {
                  if (error == null) return SizedBox();
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
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => vm.scanError.value = null,
                          child: Icon(Icons.close, color: Theme.of(context).colorScheme.error, size: 20),
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
                        if (devices.isEmpty)
                          ListView(
                            children: [
                              SizedBox(height: 60),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.media_bluetooth_off,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.38),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      context.translate('No devices found'),
                                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                        context.translate('Searching for devices...'),
                                        style: TextStyle(fontSize: 16),
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
          );
        },
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
      trailing: Icon(Icons.chevron_right),
      onTap: () => _showAddDeviceSheet(context, vm, deviceDesc),
    );
  }

  Widget _buildUnprovisionedTile(BuildContext context, DeviceDiscoveryViewModel vm, String name) {
    return ListTile(
      leading: Container(
        height: 48,
        width: 48,
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
            side: BorderSide(width: 1.5, color: Theme.of(context).colorScheme.secondaryContainer),
          ),
        ),
        child: Icon(Icons.bluetooth, size: 24, color: Theme.of(context).colorScheme.onSecondaryContainer),
      ),
      title: Text(name),
      subtitle: Text(context.translate('Ready to provision')),
      trailing: Icon(Icons.chevron_right),
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
