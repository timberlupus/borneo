import 'package:borneo_app/core/services/devices/ble_provisioner.dart';
import 'package:borneo_app/features/devices/models/ble_provision_state.dart';
import 'package:borneo_app/features/devices/view_models/provisioning_progress_view_model.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class ProvisioningProgressScreen extends StatelessWidget {
  final String deviceName;
  final String ssid;
  final String password;

  const ProvisioningProgressScreen({super.key, required this.deviceName, required this.ssid, required this.password});

  void stop() {
    // We can't really stop the ble operation easily once started in this flow without complex cancellation logic
    // But we can pop the screen.
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProvisioningProgressViewModel(
        context.read<IBleProvisioner>(),
        deviceName,
        ssid,
        password,
        globalEventBus: context.read<EventBus>(),
      )..startProvisioning(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.translate('Provisioning')),
          actions: [
            Builder(
              builder: (ctx) {
                return TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.translate("Stop"), style: TextStyle(color: Theme.of(ctx).colorScheme.onPrimary)),
                );
              },
            ),
          ],
        ),
        body: Consumer<ProvisioningProgressViewModel>(
          builder: (context, vm, child) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.wifi_tethering_outlined, size: 128, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        _buildStep(context, vm, BleProvisioningState.sendingCredentials, 'Sending Credentials'),
                        _buildStep(context, vm, BleProvisioningState.connectingToWifi, 'Connecting to WiFi'),
                        //_buildStep(context, vm, BleProvisioningState.checkingStatus, 'Checking Status'),
                        _buildStep(context, vm, BleProvisioningState.registeringDevice, 'Registering Device'),
                      ],
                    ),
                  ),

                  if (vm.state == BleProvisioningState.success)
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(context.translate('Provisioning Successful!')),
                          const SizedBox(height: 16),
                          // Auto-pop after showing success for 2 seconds
                          Builder(
                            builder: (ctx) {
                              Future.delayed(const Duration(seconds: 2), () {
                                if (ctx.mounted) {
                                  // Pop back to discovery screen with refresh flag
                                  Navigator.pop(context, {
                                    'refresh': true,
                                  }); // Pop Progress (back to discovery due to pushReplacement)
                                }
                              });
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),

                  if (vm.state == BleProvisioningState.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Column(
                        children: [
                          Icon(Icons.error, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text(
                            vm.errorMessage ?? context.translate('Unknown Error'),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(context.translate('Close')),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, ProvisioningProgressViewModel vm, BleProvisioningState step, String label) {
    // Determine status of this step
    bool isCompleted = vm.state.index > step.index;
    bool isCurrent = vm.state == step;
    bool isPending = vm.state.index < step.index;

    Widget icon;
    if (isCompleted || vm.state == BleProvisioningState.success) {
      icon = Icon(Icons.check, color: Theme.of(context).colorScheme.primary);
    } else if (isCurrent && vm.state != BleProvisioningState.failed) {
      icon = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (vm.state == BleProvisioningState.failed && isCurrent) {
      icon = Icon(Icons.close, color: Theme.of(context).colorScheme.error);
    } else {
      icon = Icon(Icons.circle_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: Center(child: icon)),
          const SizedBox(width: 16),
          Text(
            context.translate(label),
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isPending
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
