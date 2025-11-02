import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class DeviceStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final VoidCallback? onReconnect;
  final bool isReconnecting;
  final int? reconnectCountdownSeconds;

  const DeviceStatusIndicator({
    super.key,
    required this.isOnline,
    this.onReconnect,
    this.isReconnecting = false,
    this.reconnectCountdownSeconds,
  });

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
              onPressed: isReconnecting ? null : onReconnect,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isReconnecting
                    ? SizedBox(
                        key: const ValueKey('reconnect-progress'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.error),
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        key: const ValueKey('reconnect-icon'),
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
              ),
              label: Builder(
                builder: (context) {
                  final rawCountdown = reconnectCountdownSeconds ?? 0;
                  final int countdown = rawCountdown < 0 ? 0 : (rawCountdown > 99 ? 99 : rawCountdown);
                  final labelText = isReconnecting
                      ? '${context.translate("Connecting...")} (${countdown}s)'
                      : context.translate('Reconnect');
                  return Text(
                    labelText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
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
