import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP BLE Provisioning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const ProvisioningHomePage(),
    );
  }
}

class ProvisioningHomePage extends StatefulWidget {
  const ProvisioningHomePage({super.key});

  @override
  State<ProvisioningHomePage> createState() => _ProvisioningHomePageState();
}

class _ProvisioningHomePageState extends State<ProvisioningHomePage> {
  final _flutterEspBleProvPlugin = FlutterEspBleProv();
  final _formKey = GlobalKey<FormState>();

  // Stepper state
  int _currentStep = 0;

  // Logic state
  bool _isScanningBle = false;
  bool _isScanningWifi = false;
  bool _isProvisioning = false;
  List<String> _devices = [];
  List<WifiNetwork> _networks = [];

  String? _selectedDeviceName;
  WifiNetwork? _selectedNetwork;

  // Controllers
  final _prefixController = TextEditingController(text: 'PROV_');
  final _proofOfPossessionController = TextEditingController(text: 'abcd1234');
  final _passphraseController = TextEditingController();

  @override
  void dispose() {
    _prefixController.dispose();
    _proofOfPossessionController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _scanBleDevices() async {
    if (_isScanningBle) return;

    // Reset selection when rescanning
    setState(() {
      _isScanningBle = true;
      _devices = [];
      _selectedDeviceName = null;
    });

    try {
      final prefix = _prefixController.text.trim();
      if (prefix.isEmpty) {
        _showSnackBar('Please enter a device prefix', isError: true);
        return;
      }

      final scannedDevices = await _flutterEspBleProvPlugin.scanBleDevices(
        prefix,
      );

      if (!mounted) return;

      setState(() {
        _devices = scannedDevices;
      });

      if (scannedDevices.isEmpty) {
        _showSnackBar('No devices found with prefix "$prefix"', isError: true);
      } else {
        _showSnackBar('Found ${scannedDevices.length} devices');
      }
    } catch (e) {
      if (mounted) _showSnackBar('BLE Scan failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isScanningBle = false);
    }
  }

  Future<void> _scanWifiNetworks() async {
    if (_isScanningWifi || _selectedDeviceName == null) return;

    setState(() {
      _isScanningWifi = true;
      _networks = [];
      _selectedNetwork = null;
    });

    try {
      final pop = _proofOfPossessionController.text.trim();
      if (pop.isEmpty) {
        _showSnackBar('Please enter Proof of Possession', isError: true);
        return;
      }

      final networks = await _flutterEspBleProvPlugin
          .scanWifiNetworksWithDetails(_selectedDeviceName!, pop);

      if (!mounted) return;

      setState(() {
        _networks = networks;
      });

      if (networks.isEmpty) {
        _showSnackBar('No WiFi networks found', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('WiFi Scan failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isScanningWifi = false);
    }
  }

  Future<void> _provision() async {
    if (_isProvisioning) return;
    if (_selectedDeviceName == null || _selectedNetwork == null) return;

    setState(() => _isProvisioning = true);

    try {
      final pop = _proofOfPossessionController.text.trim();
      final passphrase = _passphraseController.text.trim();

      final success = await _flutterEspBleProvPlugin.provisionWifi(
        _selectedDeviceName!,
        pop,
        _selectedNetwork!.ssid,
        passphrase,
      );

      if (!mounted) return;

      if (success == true) {
        _showSuccessDialog();
      } else {
        _showSnackBar('Provisioning failed', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProvisioning = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(
          'Device $_selectedDeviceName has been successfully provisioned!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentStep = 0;
                _selectedDeviceName = null;
                _selectedNetwork = null;
                _passphraseController.clear();
              });
            },
            child: const Text('Provision Another'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP Device Setup'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _handleStepContinue,
          onStepCancel: _handleStepCancel,
          controlsBuilder: (context, details) {
            return const SizedBox.shrink(); // We'll implement custom controls inside steps
          },
          steps: [_buildBleStep(), _buildWifiStep(), _buildProvisionStep()],
        ),
      ),
    );
  }

  void _handleStepContinue() {
    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    }
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Step _buildBleStep() {
    return Step(
      title: const Text('Find Device'),
      subtitle: Text(_selectedDeviceName ?? 'Scan for ESP devices'),
      isActive: _currentStep >= 0,
      state: _selectedDeviceName != null
          ? StepState.complete
          : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _prefixController,
                  decoration: const InputDecoration(
                    labelText: 'Device Prefix',
                    hintText: 'e.g. PROV_',
                    prefixIcon: Icon(Icons.bluetooth_searching),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isScanningBle ? null : _scanBleDevices,
                child: _isScanningBle
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Scan'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_devices.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final isSelected = _selectedDeviceName == device;
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(device),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedDeviceName = device;
                      });
                      _scanWifiNetworks(); // Pre-load details for next step
                      if (_currentStep == 0) _handleStepContinue();
                    },
                  );
                },
              ),
            ),
          ] else if (!_isScanningBle) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No devices found yet. Enter prefix and tap Scan.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Step _buildWifiStep() {
    return Step(
      title: const Text('Select Network'),
      subtitle: Text(_selectedNetwork?.ssid ?? 'Choose WiFi for device'),
      isActive: _currentStep >= 1,
      state: _selectedNetwork != null ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _proofOfPossessionController,
            decoration: const InputDecoration(
              labelText: 'Proof of Possession',
              hintText: 'Device security key',
              prefixIcon: Icon(Icons.vpn_key),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connected to: ${_selectedDeviceName ?? "None"}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isScanningWifi ? null : _scanWifiNetworks,
                  tooltip: 'Rescan Networks',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isScanningWifi)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_networks.isNotEmpty)
            Container(
              height: 250, // Limit height for scrollable list
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _networks.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final network = _networks[index];
                  final isSelected = _selectedNetwork?.ssid == network.ssid;

                  IconData signalIcon;
                  Color signalColor;
                  if (network.rssi > -50) {
                    signalIcon = Icons.wifi;
                    signalColor = Colors.green;
                  } else if (network.rssi > -70) {
                    signalIcon = Icons.wifi;
                    signalColor = Colors.orange;
                  } else {
                    signalIcon = Icons.wifi_off; // icon for weak
                    signalColor = Colors.red;
                  }

                  return ListTile(
                    leading: Icon(signalIcon, color: signalColor),
                    title: Text(network.ssid),
                    subtitle: Text('${network.rssi} dBm'),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedNetwork = network);
                      if (_currentStep == 1) _handleStepContinue();
                    },
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No networks found. Check POP key and rescan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: _handleStepCancel,
                child: const Text('Back'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Step _buildProvisionStep() {
    return Step(
      title: const Text('Provision'),
      isActive: _currentStep >= 2,
      state: StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSummaryRow('Device', _selectedDeviceName ?? '-'),
                  const Divider(),
                  _buildSummaryRow('Wifi SSID', _selectedNetwork?.ssid ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passphraseController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'WiFi Password',
              hintText: 'Enter network password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onFieldSubmitted: (_) => _provision(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isProvisioning ? null : _provision,
            icon: _isProvisioning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(
              _isProvisioning ? 'Provisioning...' : 'Start Provisioning',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _handleStepCancel,
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
