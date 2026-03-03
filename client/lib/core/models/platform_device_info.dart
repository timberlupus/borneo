import 'package:screen_corner_radius/screen_corner_radius.dart';

/// Immutable device-specific information that is determined at startup.
///
/// Currently the only data we expose is the screen corner radius, but more
/// fields (e.g. platform version, safe area insets, etc.) could be added in
/// the future.
class PlatformDeviceInfo {
  /// Rounded corner geometry of the current device's screen.
  final ScreenRadius screenCornerRadius;

  const PlatformDeviceInfo({required this.screenCornerRadius});
}
