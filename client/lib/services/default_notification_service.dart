import 'package:borneo_app/services/inotification_service.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class DefaultNotificationService implements INotificationService {
  @override
  void showError(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.error,
      title: Text(title),
      description: body != null ? Text(body) : null,
    );
  }

  @override
  void showInfo(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.info,
      title: Text(title),
      description: body != null ? Text(body) : null,
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
    );
  }

  @override
  void showWarning(String title, {String? body}) {
    toastification.show(
      type: ToastificationType.warning,
      title: Text(title),
      description: body != null ? Text(body) : null,
    );
  }
}
