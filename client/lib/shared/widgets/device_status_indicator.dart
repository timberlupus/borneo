import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class DeviceStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final VoidCallback? onReconnect;

  const DeviceStatusIndicator({super.key, required this.isOnline, this.onReconnect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        border: Border(bottom: BorderSide(color: theme.colorScheme.error, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_off, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.translate('Device offline'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onReconnect != null)
            TextButton.icon(
              onPressed: onReconnect,
              icon: Icon(Icons.refresh, size: 16, color: theme.colorScheme.error),
              label: Text(
                context.translate('Reconnect'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
