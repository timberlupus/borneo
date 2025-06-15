import 'package:borneo_app/core/services/i_app_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class DefaultAppNotificationService implements IAppNotificationService {
  @override
  void showError(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.error,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 5),
    );
  }

  @override
  void showInfo(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.info,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 5),
      closeOnClick: true,
      dragToClose: true,
    );
  }

  @override
  void showNotificationWithAction(String title, {String? body, required Function onTapAction}) {
    toastification.show(
      type: ToastificationType.info,
      title: Text(title),
      description: body != null ? Text(body) : null,
    );
  }

  @override
  void showSuccess(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.success,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 3),
      closeOnClick: true,
      dragToClose: true,
    );
  }

  @override
  void showWarning(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.warning,
      title: Text(title),
      description: body != null ? Text(body) : null,
      autoCloseDuration: Duration(seconds: 5),
    );
  }
}
