abstract class AppRoutes {
  static const kMainScreen = '/';
  static const kScreens = '/scenes';
  static const kGroups = '/groups';
  static const kDevices = '/devices';
  static const kAccount = '/account';
  static const kDeviceDiscovery = '/devices/discovery';

  static String makeDeviceScreenRoute(String driverID) {
    if (driverID.isEmpty) {
      throw ArgumentError('The argument cannot be empty', 'driverID');
    }
    return '/devices/$driverID';
  }
}
