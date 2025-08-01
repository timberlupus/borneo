import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

/// Widget displayed when no device groups exist
class EmptyGroupsWidget extends StatelessWidget {
  final VoidCallback onCreateGroup;

  const EmptyGroupsWidget({required this.onCreateGroup, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(context.translate('No Device Groups'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              context.translate('Create groups to better organize your devices'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add),
              label: Text(context.translate('Create First Group')),
            ),
          ],
        ),
      ),
    );
  }
}
