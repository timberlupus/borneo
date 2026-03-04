/// Compile-time flag that controls whether Demo Mode is *on by default*
/// when the app is first installed / launched.
///
/// Demo Mode itself is always available in production builds; this constant
/// only determines the initial value that is written to SharedPreferences on
/// first run, making it easy for developers to test without manually toggling
/// the setting.
///
/// Usage:
///   flutter run  --dart-define=DEMO_MODE_DEFAULT=true
const bool kDefaultDemoMode = bool.fromEnvironment('DEMO_MODE_DEFAULT', defaultValue: false);
