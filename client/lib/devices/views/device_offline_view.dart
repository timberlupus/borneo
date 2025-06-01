import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class DeviceOfflineView extends StatelessWidget {
  const DeviceOfflineView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsetsGeometry.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              context.translate('Device is offline'),
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              context.translate('The device is currently offline. Please check the network or power connection.'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back, size: 24),
              label: Text(context.translate('Close')),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: theme.textTheme.titleMedium,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
