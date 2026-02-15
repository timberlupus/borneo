import 'package:borneo_app/devices/borneo/lyfi/view_models/controller_settings_view_model.dart';
import 'package:borneo_app/shared/widgets/bottom_sheet_picker.dart';
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
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(context.translate("Controller Settings"))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(context.translate("Controller Settings"))),
            body: Center(child: Text(context.translate('Initialization failed'))),
          );
        }

        return ChangeNotifierProvider.value(
          value: widget.vm,
          builder: (context, child) => Consumer<ControllerSettingsViewModel>(
            builder: (context, vm, child) => GenericSettingsScreen(
              title: context.translate("Controller Settings"),
              appBarActions: _buildAppBarActions(context),
              children: _buildSettingGroups(context),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      Selector<ControllerSettingsViewModel, bool>(
        selector: (context, vm) => vm.hasChanges,
        builder: (context, hasChanges, child) => TextButton.icon(
          key: const ValueKey('submit'),
          onPressed: context.read<ControllerSettingsViewModel>().canSubmit
              ? () => _showSubmitConfirmationDialog(context)
              : null,
          icon: const Icon(Icons.check, size: 24),
          label: Text(context.translate('Apply')),
        ),
      ),
    ];
  }

  List<Widget> _buildSettingGroups(BuildContext context) {
    // const rightChevron = CupertinoListTileChevron();
    final tileColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return <Widget>[
      GenericSettingsGroup(
        title: context.translate('LED CONFIGURATION'),
        children: [
          if (widget.vm.pwmFreq.available)
            Selector<ControllerSettingsViewModel, int?>(
              selector: (context, vm) => vm.pwmFreq.value,
              builder: (context, pwmFreq, child) => ListTile(
                dense: true,
                tileColor: tileColor,
                title: Text(context.translate('PWM frequency')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(_formatPwmFreq(pwmFreq)), const SizedBox(width: 8), const Icon(Icons.chevron_right)],
                ),
                onTap: () => _showPwmFreqPicker(context),
              ),
            ),
        ],
      ),

      GenericSettingsGroup(
        title: context.translate('LED CHANNELS'),
        children: [
          if (widget.vm.channelCountSetting.available)
            Selector<ControllerSettingsViewModel, int?>(
              selector: (context, vm) => vm.channelCountSetting.value,
              builder: (context, channelCount, child) => ListTile(
                dense: true,
                tileColor: tileColor,
                title: Text(context.translate('Enabled channel count')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('$channelCount'), const SizedBox(width: 8), const Icon(Icons.chevron_right)],
                ),
                onTap: () => _showChannelCountPicker(context),
              ),
            ),
          ...List<Widget>.generate(widget.vm.channels.length, (index) {
            final channel = widget.vm.channels[index];
            final name = channel.name;
            final colorStr = channel.color;
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
                      onChanged: channel.setName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    icon: const Icon(Icons.palette_outlined),
                    tooltip: context.translate('Pick color'),
                    onPressed: () => _openColorPicker(channel),
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
          if (widget.vm.overpowerEnabled.available)
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
          if (widget.vm.overpowerCutoff.available)
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
          if (widget.vm.overtempEnabled.available)
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
          if (widget.vm.overtempCutoff.available)
            Selector<ControllerSettingsViewModel, int?>(
              selector: (context, vm) => vm.overtempCutoff.value,
              builder: (context, cutoff, child) => ListTile(
                dense: true,
                tileColor: tileColor,
                title: Text(context.translate('Overtemperature cut-off')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('$cutoff ℃'), const SizedBox(width: 8), const Icon(Icons.chevron_right)],
                ),
                onTap: () => _showOvertempCutoffPicker(context),
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

  void _openColorPicker(ChannelSettingsEntry channel) {
    final initialColor = _parseHexColor(channel.color);

    showDialog(
      context: context,
      builder: (ctx) {
        Color selected = initialColor;
        return AlertDialog(
          title: Text(context.translate('Pick color')),
          content: SingleChildScrollView(
            child: ColorPicker(
              hexInputBar: true,
              enableAlpha: false,
              pickerColor: initialColor,
              onColorChanged: (c) => selected = c,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.translate('Cancel'))),
            TextButton(
              onPressed: () {
                _setChannelColorFromPicker(channel, selected);
                Navigator.of(ctx).pop();
              },
              child: Text(context.translate('Apply')),
            ),
          ],
        );
      },
    );
  }

  void _setChannelColorFromPicker(ChannelSettingsEntry channel, Color color) {
    final hex = _colorToHex(color);
    channel.setColor(hex);
  }

  void _showChannelCountPicker(BuildContext context) {
    final maxChannels = widget.vm.lyfiDeviceInfo.channelCountMax;
    final currentValue = widget.vm.channelCountSetting.value;

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select channel count'),
      items: List.generate(maxChannels, (index) => '${index + 1}'),
      selectedIndex: currentValue - 1,
      onItemSelected: (index) {
        widget.vm.channelCountSetting.setValue(index + 1);
      },
    );
  }

  String _formatPwmFreq(int? freq) {
    if (freq == null) return '';
    if (freq >= 1000) {
      return '${(freq / 1000).round()} kHz';
    } else {
      return '$freq Hz';
    }
  }

  void _showPwmFreqPicker(BuildContext context) {
    final currentValue = widget.vm.pwmFreq.value;
    final options = [
      {'value': 500, 'label': '500 Hz'},
      {'value': 1000, 'label': '1 kHz'},
      {'value': 2000, 'label': '2 kHz'},
      {'value': 3000, 'label': '3 kHz'},
      {'value': 4000, 'label': '4 kHz'},
      {'value': 8000, 'label': '8 kHz'},
      {'value': 19000, 'label': '19 kHz'},
    ];

    final currentIndex = options.indexWhere((option) => option['value'] == currentValue);

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select PWM frequency'),
      items: options.map((option) => option['label'] as String).toList(),
      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
      onItemSelected: (index) {
        final selectedOption = options[index];
        widget.vm.pwmFreq.setValue(selectedOption['value'] as int);
      },
    );
  }

  void _showOvertempCutoffPicker(BuildContext context) {
    final currentValue = widget.vm.overtempCutoff.value;
    final options = [
      {'value': 55, 'label': '55 ℃'},
      {'value': 60, 'label': '60 ℃'},
      {'value': 65, 'label': '65 ℃'},
      {'value': 70, 'label': '70 ℃'},
      {'value': 75, 'label': '75 ℃'},
    ];

    final currentIndex = options.indexWhere((option) => option['value'] == currentValue);

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select overtemperature cut-off'),
      items: options.map((option) => option['label'] as String).toList(),
      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
      onItemSelected: (index) {
        final selectedOption = options[index];
        widget.vm.overtempCutoff.setValue(selectedOption['value'] as int);
      },
    );
  }

  String _colorToHex(Color color) {
    final r = color.intRed.toRadixString(16).padLeft(2, '0');
    final g = color.intGreen.toRadixString(16).padLeft(2, '0');
    final b = color.intBlue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
