import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/views/devices/device_group_selection_sheet.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

import '../../services/device_manager.dart';
import '../../view_models/devices/device_discovery_view_model.dart';

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Card(
              margin: const EdgeInsets.all(0),
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Selector<DeviceDiscoveryViewModel, int>(
                      selector: (_, vm) => vm.discoveredCount,
                      builder:
                          (context, value, child) => Text(
                            value.toString(),
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                            textAlign: TextAlign.center,
                          ),
                    ),
                    Text(
                      'Responding Devices',
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.all(0),
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Consumer<DeviceDiscoveryViewModel>(
                      builder:
                          (context, vm, child) => Text(
                            vm.newDeviceCount.toString(),
                            style: Theme.of(
                              context,
                            ).textTheme.headlineLarge?.copyWith(color: Theme.of(context).colorScheme.secondary),
                            textAlign: TextAlign.center,
                          ),
                    ),
                    Text('New Devices', style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StartStopButton extends StatelessWidget {
  const StartStopButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDiscoveryViewModel>(
      builder: (context, vm, child) {
        return ElevatedButton(
          onPressed: (!vm.isBusy && (!vm.isSmartConfigEnabled || vm.isFormValid)) ? vm.startStopDiscovery : null,
          child:
              vm.isDiscovering
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vm.isDiscovering)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.inversePrimary),
                          ),
                        ),
                      SizedBox(width: 16),
                      Text('Stop'),
                    ],
                  )
                  : Text('Start'),
        );
      },
    );
  }
}

class SmartConfigFormPanel extends StatefulWidget {
  const SmartConfigFormPanel({super.key});

  @override
  State createState() => _SmartConfigFormPanelState();
}

class _SmartConfigFormPanelState extends State<SmartConfigFormPanel> {
  late TextEditingController _ssidController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Expanded(child: Text('Provisioning', style: Theme.of(context).textTheme.titleMedium)),
                Consumer<DeviceDiscoveryViewModel>(
                  builder:
                      (context, vm, child) => Switch(
                        value: vm.isSmartConfigEnabled,
                        onChanged: !vm.isDiscovering && !vm.isBusy ? vm.toggleSmartConfigSwitch : null,
                      ),
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.all(0),
            child: Column(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Consumer<DeviceDiscoveryViewModel>(
                        builder: (context, vm, child) {
                          _ssidController.text = vm.ssid;
                          return TextField(
                            controller: _ssidController,
                            onChanged: (value) {
                              vm.ssid = value;
                            },
                            enabled: !vm.isDiscovering && !vm.isBusy && vm.isSmartConfigEnabled,
                            decoration: InputDecoration(
                              labelText: "2.4G WiFi Name (SSID)",
                              border: InputBorder.none,
                              icon: Icon(
                                Icons.wifi,
                                color:
                                    !vm.isSmartConfigEnabled
                                        ? Theme.of(context).disabledColor
                                        : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8.0),
                      child: const Divider(height: 1, thickness: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Consumer<DeviceDiscoveryViewModel>(
                        builder:
                            (context, vm, child) => TextField(
                              controller: _passwordController,
                              onChanged: (value) {
                                vm.password = value;
                              },
                              enabled: !vm.isDiscovering && !vm.isBusy && vm.isSmartConfigEnabled,
                              decoration: InputDecoration(
                                labelText: "2.4G WiFi Password",
                                border: InputBorder.none,
                                icon: Icon(
                                  Icons.lock,
                                  color:
                                      !vm.isSmartConfigEnabled
                                          ? Theme.of(context).disabledColor
                                          : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8.0),
                      child: const Divider(height: 1, thickness: 1),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewDeviceAddedSnackBarListener extends StatelessWidget {
  final Widget child;
  const NewDeviceAddedSnackBarListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Selector<DeviceDiscoveryViewModel, DeviceEntity?>(
      selector: (_, viewModel) => viewModel.lastestAddedDevice,
      builder: (context, lastestAdded, child) {
        if (lastestAdded != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            toastification.dismissAll();
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.fillColored,
              title: Text(context.translate('A new device has been added.')),
              description: Text(lastestAdded.name),
              autoCloseDuration: const Duration(seconds: 3),
              icon: const Icon(Icons.device_hub),
            );

            // 在 toast 关闭后清除状态
            /*
            Future.delayed(const Duration(seconds: 3), () {
              if (!vm.isDisposed) {
                vm.clearAddedDevice();
              }
            });
            */
          });
        }
        return child!;
      },
      child: child,
    );
  }
}

class DeviceDiscoveryScreen extends StatelessWidget {
  const DeviceDiscoveryScreen({super.key});

  DeviceDiscoveryViewModel createViewModel(BuildContext context) => DeviceDiscoveryViewModel(
    context.read<Logger>(),
    context.read<GroupManager>(),
    context.read<DeviceManager>(),
    globalEventBus: context.read<EventBus>(),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeviceDiscoveryViewModel>(
      create: createViewModel,
      builder:
          (context, child) => FutureBuilder(
            future:
                context.read<DeviceDiscoveryViewModel>().isInitialized
                    ? null
                    : context.read<DeviceDiscoveryViewModel>().initialize(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(body: Center(child: CircularProgressIndicator()));
              } else if (snapshot.hasError) {
                return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
              } else {
                return Scaffold(
                  appBar: AppBar(title: Text('Add new device'), backgroundColor: Theme.of(context).colorScheme.surface),
                  body: buildBody(context),
                );
              }
            },
          ),
    );
  }

  Widget buildBody(BuildContext context) {
    final vm = context.read<DeviceDiscoveryViewModel>();
    //final screenSize = MediaQuery.of(context).size;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (!vm.isDiscovering && !vm.isBusy) {
          Navigator.of(context).pop(vm.newDeviceCount > 0);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input Fields
                  SmartConfigFormPanel(),
                  SizedBox(height: 8),
                  // Start/Stop Button
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    width: double.infinity,
                    child: StartStopButton(),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
            ValueListenableBuilder<List<SupportedDeviceDescriptor>>(
              valueListenable: vm.discoveredDevices,
              builder: (context, devices, child) => devices.isNotEmpty ? child! : const SizedBox(height: 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(context.translate('Discovered Devices:'), style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<SupportedDeviceDescriptor>>(
                valueListenable: vm.discoveredDevices,
                builder:
                    (context, value, child) => ListView.separated(
                      separatorBuilder:
                          (BuildContext context, int index) => DecoratedBox(
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer),
                            child: Divider(height: 1, indent: 16, color: Theme.of(context).colorScheme.surface),
                          ),
                      itemCount: vm.discoveredDevices.value.length,
                      itemBuilder: (context, index) {
                        final user = vm.discoveredDevices.value[index];
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainer,
                          title: Text(user.name, style: Theme.of(context).textTheme.bodyLarge),
                          subtitle: Text(user.address.toString(), style: Theme.of(context).textTheme.bodySmall),
                          trailing: Consumer<DeviceDiscoveryViewModel>(
                            builder:
                                (context, vm, child) => IconButton.filledTonal(
                                  onPressed:
                                      vm.isBusy || vm.isDiscovering
                                          ? null
                                          : () => _showAddDeviceSheet(context, vm, vm.discoveredDevices.value[index]),
                                  icon: child as Icon,
                                ),
                            child: Icon(Icons.add_outlined),
                          ),
                        );
                      },
                    ),
              ),
            ),
            NewDeviceAddedSnackBarListener(child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _showAddDeviceSheet(BuildContext context, DeviceDiscoveryViewModel vm, SupportedDeviceDescriptor deviceInfo) {
    showModalBottomSheet(
      context: context,
      builder:
          (BuildContext context) => DeviceGroupSelectionSheet(
            availableGroups: vm.availableGroups,
            onTapGroup: (g) => vm.addNewDevice(deviceInfo, g),
            title: 'Registry "${deviceInfo.name}"',
            subtitle: 'Select the group to which the new device belongs:',
          ),
    );
  }
}
