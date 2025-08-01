import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  final Logger? logger;
  final IAppNotificationService notification;
  const UrlLauncherService({required this.notification, this.logger});

  Future<void> open(final String url) async {
    final uri = Uri.parse(url);
    bool failed = true;
    try {
      failed = !await launchUrl(uri);
    } catch (e, stackTrace) {
      failed = true;
      logger?.e(e.toString(), error: e, stackTrace: stackTrace);
    } finally {
      if (failed) {
        notification.showError('URL', body: url);
      }
    }
  }

  Future<bool> canOpen(final String url) async {
    return await canLaunchUrl(Uri.parse(url));
  }
}
