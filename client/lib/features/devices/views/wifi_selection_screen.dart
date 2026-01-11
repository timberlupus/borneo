import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/features/devices/view_models/wifi_selection_view_model.dart';
import 'package:borneo_app/features/devices/views/provisioning_progress_screen.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class WifiSelectionScreen extends StatelessWidget {
  final String deviceName;

  const WifiSelectionScreen({super.key, required this.deviceName});

  Icon _getWifiIcon(int rssi) {
    // RSSI typically ranges from -100 (weak) to 0 (strong)
    if (rssi >= -50) {
      return Icon(Icons.wifi, color: Colors.green); // Strong signal
    } else if (rssi >= -70) {
      return Icon(Icons.wifi_2_bar, color: Colors.yellow); // Good signal
    } else if (rssi >= -80) {
      return Icon(Icons.wifi_1_bar, color: Colors.orange); // Weak signal
    } else {
      return Icon(Icons.wifi_1_bar, color: Colors.red); // Very weak signal
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          WifiSelectionViewModel(context.read<IDeviceManager>(), deviceName, globalEventBus: context.read<EventBus>())
            ..onInitialize(),
      child: Scaffold(
        appBar: AppBar(title: Text(context.translate('Select WiFi'))),
        body: Consumer<WifiSelectionViewModel>(
          builder: (context, vm, child) {
            if (vm.isBusy) {
              return Center(child: CircularProgressIndicator());
            }
            if (vm.networks == null || vm.networks!.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => await vm.scanNetworks(),
                child: ListView(
                  children: [
                    SizedBox(height: 100),
                    Center(child: Text(context.translate('No WiFi networks found'))),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => await vm.scanNetworks(),
              child: ListView.separated(
                itemCount: vm.networks!.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.38)),
                itemBuilder: (context, index) {
                  final network = vm.networks![index];
                  return ListTile(
                    title: Text(network.ssid),
                    leading: _getWifiIcon(network.rssi),
                    trailing: Icon(Icons.lock, size: 16), // TODO FIXME
                    onTap: () => _showPasswordDialog(context, network.ssid),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, String ssid) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.translate('Enter Password for %s').replaceAll('%s', ssid)),
          content: TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              hintText: context.translate('Password'),
              suffixIcon: IconButton(
                icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => obscurePassword = !obscurePassword),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.translate('Cancel'))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProvisioningProgressScreen(
                      deviceName: deviceName,
                      ssid: ssid,
                      password: passwordController.text,
                    ),
                  ),
                );
              },
              child: Text(context.translate('Provision')),
            ),
          ],
        ),
      ),
    );
  }
}
