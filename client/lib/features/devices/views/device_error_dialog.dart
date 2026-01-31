import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class DeviceErrorDialog extends StatelessWidget {
  final String errorMessage;

  const DeviceErrorDialog({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.translate('Device Error')),
      content: Text(errorMessage),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.translate('OK')))],
    );
  }
}
