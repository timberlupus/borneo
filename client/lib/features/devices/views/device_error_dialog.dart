import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class DeviceErrorDialog extends StatelessWidget {
  final String errorMessage;

  const DeviceErrorDialog({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(
        context.translate('Device Error'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error),
      ),
      content: Text(errorMessage),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.translate('OK')))],
    );
  }
}
