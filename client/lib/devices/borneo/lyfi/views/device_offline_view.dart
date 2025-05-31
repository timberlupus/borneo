import 'package:flutter/material.dart';

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
            Icon(Icons.cloud_off, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Device is offline',
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onBackground),
            ),
            const SizedBox(height: 12),
            Text(
              'The device is currently offline. Please check the network or power connection.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onBackground.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: handle reconnect event externally
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
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
