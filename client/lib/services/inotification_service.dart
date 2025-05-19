abstract class INotificationService {
  void showSuccess(String title, {String? body});
  void showError(String title, {String? body});
  void showWarning(String title, {String? body});
  void showInfo(String title, {String? body});
  void showNotificationWithAction(String title, {String? body, required Function onTapAction});
}
