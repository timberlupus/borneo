import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class AppNotificationServiceImpl implements IAppNotificationService {
  final ThemeData Function() _getTheme;
  final GlobalKey<NavigatorState> _navigatorKey;

  bool _errorDialogShowing = false;

  AppNotificationServiceImpl({required ThemeData Function() getTheme, required GlobalKey<NavigatorState> navigatorKey})
    : _getTheme = getTheme,
      _navigatorKey = navigatorKey;

  @override
  void showError(String title, {String? body}) {
    // Deduplicate: if an error dialog is already visible, ignore repeat calls.
    if (_errorDialogShowing) return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    _errorDialogShowing = true;
    final theme = _getTheme();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog.adaptive(
        icon: Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
        title: Text(title),
        content: body != null ? SingleChildScrollView(child: Text(body)) : null,
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
      ),
    ).whenComplete(() => _errorDialogShowing = false);
  }

  @override
  void showInfo(String title, {String? body}) {
    final theme = _getTheme();
    toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 5),
      closeOnClick: true,
      dragToClose: true,
      primaryColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundColor: theme.colorScheme.onSurface,
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );
  }

  @override
  void showNotificationWithAction(String title, {String? body, required Function onTapAction}) {
    final theme = _getTheme();
    toastification.show(
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      title: Text(title),
      description: body != null ? Text(body) : null,
      primaryColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );
  }

  @override
  void showSuccess(String title, {String? body}) {
    final theme = _getTheme();
    toastification.show(
      type: ToastificationType.success,
      style: ToastificationStyle.minimal,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 3),
      closeOnClick: true,
      dragToClose: true,
      backgroundColor: theme.colorScheme.surfaceBright,
      foregroundColor: theme.colorScheme.onSurface,
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );
  }

  @override
  void showWarning(String title, {String? body}) {
    final theme = _getTheme();
    toastification.show(
      type: ToastificationType.warning,
      style: ToastificationStyle.minimal,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 5),
      primaryColor: theme.colorScheme.error,
      backgroundColor: theme.colorScheme.errorContainer,
      foregroundColor: theme.colorScheme.onErrorContainer,
      borderSide: BorderSide(color: theme.colorScheme.outline),
    );
  }
}
