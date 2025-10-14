import 'package:borneo_app/devices/borneo/lyfi/view_models/controller_settings_view_model.dart';
import 'package:borneo_app/shared/widgets/generic_settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import 'package:provider/provider.dart';

class ControllerSettingsScreen extends StatefulWidget {
  final ControllerSettingsViewModel vm;
  const ControllerSettingsScreen(this.vm, {super.key});

  @override
  State<ControllerSettingsScreen> createState() => _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  late Future<void> _initFuture;
  late final TextEditingController _overpowerCutoffController;

  @override
  void initState() {
    super.initState();
    _overpowerCutoffController = TextEditingController();
    _initFuture = widget.vm.initialize();
  }

  @override
  void dispose() {
    _overpowerCutoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        final isInitialized = snapshot.connectionState == ConnectionState.done && !snapshot.hasError;

        return ChangeNotifierProvider.value(
          value: widget.vm,
          builder: (context, child) => GenericSettingsScreen(
            title: context.translate("Controller Settings"),
            appBarActions: _buildAppBarActions(context, snapshot, isInitialized),
            children: _buildSettingGroups(context, isInitialized),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, AsyncSnapshot<void> snapshot, bool isInitialized) {
    return [
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: snapshot.connectionState == ConnectionState.waiting
            ? const SizedBox(
                key: ValueKey('loading'),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Selector<ControllerSettingsViewModel, bool>(
                selector: (context, vm) => vm.hasChanges,
                builder: (context, hasChanges, child) => TextButton.icon(
                  key: const ValueKey('submit'),
                  onPressed: isInitialized && hasChanges ? () => _showSubmitConfirmationDialog(context) : null,
                  icon: const Icon(Icons.upload),
                  label: Text(context.translate('Submit')),
                ),
              ),
      ),
    ];
  }

  List<Widget> _buildSettingGroups(BuildContext context, bool isInitialized) {
    const rightChevron = CupertinoListTileChevron();
    final tileColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return <Widget>[
      GenericSettingsGroup(
        title: context.translate('LED CONFIGURATION'),
        children: [
          if (isInitialized && widget.vm.pwmFreq.available)
            ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('PWM frequency')),
              trailing: Selector<ControllerSettingsViewModel, int?>(
                selector: (context, vm) => vm.pwmFreq.value,
                builder: (context, pwmFreq, child) => DropdownButton<int>(
                  value: pwmFreq,
                  items: [
                    DropdownMenuItem<int>(value: 500, child: Text(context.translate("500 Hz"))),
                    DropdownMenuItem<int>(value: 1000, child: Text(context.translate("1 kHz"))),
                    DropdownMenuItem<int>(value: 2000, child: Text(context.translate("2 kHz"))),
                    DropdownMenuItem<int>(value: 3000, child: Text(context.translate("3 kHz"))),
                    DropdownMenuItem<int>(value: 4000, child: Text(context.translate("4 kHz"))),
                    DropdownMenuItem<int>(value: 8000, child: Text(context.translate("8 kHz"))),
                    DropdownMenuItem<int>(value: 19000, child: Text(context.translate("19 kHz"))),
                  ],
                  onChanged: (v) => widget.vm.pwmFreq.setValue(v!),
                ),
              ),
            ),
        ],
      ),

      /*
      GenericSettingsGroup(
        title: context.translate('LED CHANNELS'),
        children: [
          ListTile(
            dense: true,
            tileColor: tileColor,
            title: Text('CH0'),
            leading: Icon(Icons.circle, color: Color.fromARGB(255, 196, 44, 44)),
            trailing: rightChevron,
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            title: Text('CH1'),
            leading: Icon(Icons.circle, color: Color.fromARGB(255, 196, 44, 44)),
            trailing: rightChevron,
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            title: Text('CH2'),
            leading: Icon(Icons.circle, color: Color.fromARGB(255, 196, 44, 44)),
            trailing: rightChevron,
          ),
        ],
      ),
      */

      // Thermal
      /*
      GenericSettingsGroup(
        title: context.translate('THERMAL MANAGEMENT'),
        children: [
          SwitchListTile.adaptive(
            dense: true,
            tileColor: tileColor,
            title: Text(context.translate("Thermistor enabled")),
            value: true,
            onChanged: isInitialized ? (bool value) {} : null,
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            title: Text(context.translate('Fan mode')),
            trailing: DropdownButton<int>(
              value: 0,
              items: [
                DropdownMenuItem<int>(value: 0, child: Text(context.translate("Disabled"))),
                DropdownMenuItem<int>(value: 1, child: Text(context.translate("Internal regulator"))),
                DropdownMenuItem<int>(value: 2, child: Text(context.translate("PWM Output"))),
                DropdownMenuItem<int>(value: 3, child: Text(context.translate("Internal regulator & PWM"))),
              ],
              onChanged: isInitialized ? (int? value) {} : null,
            ),
          ),
        ],
      ),
      */

      // Power & Protection
      GenericSettingsGroup(
        title: context.translate('POWER & PROTECTION'),
        children: [
          if (isInitialized && widget.vm.overpowerEnabled.available)
            Selector<ControllerSettingsViewModel, bool>(
              selector: (context, vm) => vm.overpowerEnabled.value,
              builder: (context, enabled, child) => SwitchListTile.adaptive(
                dense: true,
                tileColor: tileColor,
                title: Text(context.translate("Overpower enabled")),
                value: enabled,
                onChanged: (bool value) => context.read<ControllerSettingsViewModel>().overpowerEnabled.setValue(value),
              ),
            ),
          if (isInitialized && widget.vm.overpowerCutoff.available)
            ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Overpower cut-off')),
              trailing: Selector<ControllerSettingsViewModel, int>(
                selector: (context, vm) => vm.overpowerCutoff.value,
                builder: (context, cutoff, child) {
                  final cutoffText = cutoff.toString();
                  if (_overpowerCutoffController.text != cutoffText) {
                    _overpowerCutoffController.value = TextEditingValue(
                      text: cutoffText,
                      selection: TextSelection.collapsed(offset: cutoffText.length),
                    );
                  }
                  return SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _overpowerCutoffController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.end,
                      decoration: InputDecoration(isDense: true, hintText: '1 - 99999'),
                      onChanged: _onOverpowerCutoffChanged,
                      onSubmitted: _onOverpowerCutoffChanged,
                    ),
                  );
                },
              ),
            ),
          if (isInitialized && widget.vm.overtempEnabled.available)
            Selector<ControllerSettingsViewModel, bool>(
              selector: (context, vm) => vm.overtempEnabled.value,
              builder: (context, enabled, child) => SwitchListTile.adaptive(
                dense: true,
                tileColor: tileColor,
                title: Text(context.translate("Overtemperature enabled")),
                value: enabled,
                onChanged: (bool value) => context.read<ControllerSettingsViewModel>().overtempEnabled.setValue(value),
              ),
            ),
          if (isInitialized && widget.vm.overtempCutoff.available)
            ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Overtemperature cut-off')),
              trailing: Selector<ControllerSettingsViewModel, int?>(
                selector: (context, vm) => vm.overtempCutoff.value,
                builder: (context, cutoff, child) => DropdownButton<int>(
                  value: cutoff,
                  items: [
                    DropdownMenuItem<int>(value: 55, child: Text("55 ℃")),
                    DropdownMenuItem<int>(value: 60, child: Text("60 ℃")),
                    DropdownMenuItem<int>(value: 65, child: Text("65 ℃")),
                    DropdownMenuItem<int>(value: 70, child: Text("70 ℃")),
                    DropdownMenuItem<int>(value: 75, child: Text("75 ℃")),
                  ],
                  onChanged: (v) => widget.vm.overtempCutoff.setValue(v!),
                ),
              ),
            ),
        ],
      ),
    ];
  }

  void _onOverpowerCutoffChanged(String value) {
    if (value.isEmpty) {
      return;
    }

    final parsed = int.tryParse(value);
    if (parsed == null) {
      return;
    }

    final clamped = parsed.clamp(1, 99999);
    if (clamped != parsed) {
      final clampedText = clamped.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overpowerCutoffController.value = TextEditingValue(
          text: clampedText,
          selection: TextSelection.collapsed(offset: clampedText.length),
        );
      });
    }

    if (widget.vm.overpowerCutoff.value != clamped) {
      widget.vm.overpowerCutoff.setValue(clamped);
    }
  }

  void _showSubmitConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.translate('Confirm Submit')),
          content: Text(
            context.translate(
              'Please carefully check the configuration. Incorrect configuration may cause hardware damage or other dangerous situations. Submitting will reboot the device.\nDo you want to proceed?',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.translate('Cancel'))),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await widget.vm.submit();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.translate('Confirm')),
            ),
          ],
        );
      },
    );
  }
}
