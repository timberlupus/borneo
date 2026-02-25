import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Platform-related utilities exposed via dependency injection.
///
/// This interface exists so that tests can substitute a fake implementation
/// if desired and to avoid sprinkling `Platform`/`kIsWeb` checks throughout
/// the codebase.
abstract class PlatformService {
  /// `true` when running in a web browser.
  bool get isWeb;

  /// Conventional mobile platforms.
  bool get isAndroid;
  bool get isIOS;

  /// Conventional desktop platforms.
  bool get isWindows;
  bool get isMacOS;
  bool get isLinux;

  /// Convenience helpers.
  bool get isMobile; // android || ios
  bool get isDesktop; // windows || macos || linux
}

/// Default implementation that delegates to Flutter's and Dart's
/// built‑in platform checks.
class PlatformServiceImpl implements PlatformService {
  @override
  bool get isWeb => kIsWeb;

  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  bool get isIOS => !kIsWeb && Platform.isIOS;

  @override
  bool get isWindows => !kIsWeb && Platform.isWindows;

  @override
  bool get isMacOS => !kIsWeb && Platform.isMacOS;

  @override
  bool get isLinux => !kIsWeb && Platform.isLinux;

  @override
  bool get isMobile => isAndroid || isIOS;

  @override
  bool get isDesktop => isWindows || isMacOS || isLinux;
}
