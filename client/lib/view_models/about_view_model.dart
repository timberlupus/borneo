import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutViewModel extends BaseViewModel with ViewModelEventBusMixin {
  late final PackageInfo _packageInfo;

  PackageInfo get packageInfo => _packageInfo;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
    _isInitialized = true;
    notifyListeners();
  }
}
