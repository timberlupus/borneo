import 'package:borneo_app/devices/borneo/lyfi/view_models/controller_settings_view_model.dart';
import 'package:borneo_app/shared/widgets/generic_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class ControllerSettingsScreen extends StatefulWidget {
  final ControllerSettingsViewModel vm;
  const ControllerSettingsScreen(this.vm, {super.key});

  @override
  State<ControllerSettingsScreen> createState() => _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  late Future<void> _initFuture;
  late final TextEditingController _overpowerCutoffController;
  final List<TextEditingController> _channelNameControllers = [];

  @override
  void initState() {
    super.initState();
    _overpowerCutoffController = TextEditingController();
    _initFuture = widget.vm.initialize();
  }

  @override
  void dispose() {
    _overpowerCutoffController.dispose();
    for (final c in _channelNameControllers) {
      c.dispose();
    }
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
                  onPressed: isInitialized && context.read<ControllerSettingsViewModel>().canSubmit
                      ? () => _showSubmitConfirmationDialog(context)
                      : null,
                  icon: const Icon(Icons.upload),
                  label: Text(context.translate('Submit')),
                ),
              ),
      ),
    ];
  }

  List<Widget> _buildSettingGroups(BuildContext context, bool isInitialized) {
    // const rightChevron = CupertinoListTileChevron();
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
                    DropdownMenuItem<int>(value: 500, child: Text("500 Hz")),
                    DropdownMenuItem<int>(value: 1000, child: Text("1 kHz")),
                    DropdownMenuItem<int>(value: 2000, child: Text("2 kHz")),
                    DropdownMenuItem<int>(value: 3000, child: Text("3 kHz")),
                    DropdownMenuItem<int>(value: 4000, child: Text("4 kHz")),
                    DropdownMenuItem<int>(value: 8000, child: Text("8 kHz")),
                    DropdownMenuItem<int>(value: 19000, child: Text("19 kHz")),
                  ],
                  onChanged: (v) => widget.vm.pwmFreq.setValue(v!),
                ),
              ),
            ),
        ],
      ),

      GenericSettingsGroup(
        title: context.translate('LED CHANNELS'),
        children: [
          if (isInitialized)
            ...List<Widget>.generate(widget.vm.channelCount, (index) {
              final name = widget.vm.getChannelName(index);
              final colorStr = widget.vm.getChannelColor(index);
              if (_channelNameControllers.length <= index) {
                _channelNameControllers.add(TextEditingController(text: name));
              } else {
                final c = _channelNameControllers[index];
                if (c.text != name) c.text = name;
              }

              return ListTile(
                dense: true,
                tileColor: tileColor,
                leading: Icon(Icons.circle, color: _parseHexColor(colorStr)),
                title: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _channelNameControllers[index],
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: context.translate('Name'),
                          hintText: context.translate('1-15 characters'),
                        ),
                        inputFormatters: [LengthLimitingTextInputFormatter(15)],
                        onChanged: (val) => setState(() => widget.vm.setChannelName(index, val)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      icon: const Icon(Icons.palette_outlined),
                      tooltip: context.translate('Pick color'),
                      onPressed: () => _openColorPicker(index),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),

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

  Color _parseHexColor(String colorStr) {
    try {
      final normalized = colorStr.startsWith('#') ? colorStr.substring(1) : colorStr;
      if (normalized.length == 6) {
        final value = int.parse(normalized, radix: 16) | 0xFF000000;
        return Color(value);
      }
    } catch (_) {}
    return Theme.of(context).colorScheme.primary;
  }

  void _openColorPicker(int index) {
    final initialColor = _parseHexColor(widget.vm.getChannelColor(index));

    showDialog(
      context: context,
      builder: (ctx) {
        Color selected = initialColor;
        return AlertDialog(
          title: Text(context.translate('Pick color')),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: initialColor,
              onColorChanged: (c) => selected = c,
              availableColors: const [
                Colors.red,
                Colors.pink,
                Colors.deepPurple,
                Colors.indigo,
                Colors.blue,
                Colors.lightBlue,
                Colors.cyan,
                Colors.teal,
                Colors.green,
                Colors.lightGreen,
                Colors.lime,
                Colors.yellow,
                Colors.amber,
                Colors.orange,
                Colors.deepOrange,
                Colors.brown,
                Colors.blueGrey,
                Colors.black,
                Colors.white,
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.translate('Cancel'))),
            TextButton(
              onPressed: () {
                _setChannelColorFromPicker(index, selected);
                Navigator.of(ctx).pop();
              },
              child: Text(context.translate('Apply')),
            ),
          ],
        );
      },
    );
  }

  void _setChannelColorFromPicker(int index, Color color) {
    final hex = _colorToHex(color);
    setState(() {
      widget.vm.setChannelColor(index, hex);
    });
  }

  String _colorToHex(Color color) {
    final r = color.intRed.toRadixString(16).padLeft(2, '0');
    final g = color.intGreen.toRadixString(16).padLeft(2, '0');
    final b = color.intBlue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
