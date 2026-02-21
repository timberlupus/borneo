import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

/// Confirmation dialog for deleting a device group
class DeleteGroupDialog extends StatelessWidget {
  final String groupName;

  const DeleteGroupDialog({required this.groupName, super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Delete'),
      content: Text(
        'Are you sure you want to delete "$groupName" group?\n\n'
        'Devices in this group will be moved to the "Ungrouped" area.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.translate('Cancel'))),
        TextButton(
          key: const Key('btn_confirm_delete'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: Text(context.translate('Delete')),
        ),
      ],
    );
  }
}
