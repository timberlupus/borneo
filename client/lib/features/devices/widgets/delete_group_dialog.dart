import 'package:flutter/material.dart';

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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
