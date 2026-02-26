import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import 'package:provider/provider.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/channel_settings_view_model.dart';

class DimmerChannelView extends StatelessWidget {
  final ChannelSettingsViewModel vm;
  const DimmerChannelView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: vm,
      builder: (context, child) {
        return Consumer<ChannelSettingsViewModel>(
          builder: (context, vm, child) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            appBar: AppBar(
              title: Text(context.translate('Channel Settings')),
              actions: [
                TextButton(
                  onPressed: vm.canSave
                      ? () {
                          vm.save();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(context.translate('Save')),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              primary: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: vm.name,
                    decoration: InputDecoration(
                      labelText: context.translate('Name'),
                      hintText: context.translate('1-15 characters'),
                      errorText: vm.nameValid ? null : context.translate('Invalid name'),
                    ),
                    onChanged: vm.setName,
                  ),
                  const SizedBox(height: 24),
                  Text(context.translate('Color')),
                  const SizedBox(height: 12),
                  ColorPicker(
                    hexInputBar: true,
                    enableAlpha: false,
                    pickerColor: _parseHexColor(context, vm.color),
                    onColorChanged: (c) {
                      final hex = _colorToHex(c);
                      vm.setColor(hex);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _parseHexColor(BuildContext context, String colorStr) {
    try {
      final normalized = colorStr.startsWith('#') ? colorStr.substring(1) : colorStr;
      if (normalized.length == 6) {
        final value = int.parse(normalized, radix: 16) | 0xFF000000;
        return Color(value);
      }
    } catch (_) {}
    return Theme.of(context).colorScheme.primary;
  }

  String _colorToHex(Color color) {
    // Color.red/green/blue are deprecated; the analyzer suggests a
    // manual conversion expression.  Suppress the warning since the
    // alternative is cumbersome for this small helper.
    // ignore: deprecated_member_use
    final r = color.red.toRadixString(16).padLeft(2, '0');
    // ignore: deprecated_member_use
    final g = color.green.toRadixString(16).padLeft(2, '0');
    // ignore: deprecated_member_use
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
