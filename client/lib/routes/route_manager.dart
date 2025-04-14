// lib/routes/route_manager.dart

import 'package:borneo_app/models/devices/device_module_metadata.dart';
import 'package:borneo_app/services/devices/device_module_registry.dart';
import 'package:borneo_app/views/devices/device_discovery_screen.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../views/scenes/scenes_screen.dart';
import '../views/main_screen.dart';
import '../views/devices/devices_screen.dart';
import '../views/my_screen.dart';

class RouteManager {
  final Map<String, WidgetBuilder> _routes = {
    AppRoutes.kMainScreen: (_) => MainScreen(),
    AppRoutes.kScreens: (_) => const ScenesScreen(),
    AppRoutes.kDevices: (_) => const DevicesScreen(),
    AppRoutes.kDeviceDiscovery: (_) => const DeviceDiscoveryScreen(),
    AppRoutes.kAccount: (_) => const MyScreen(),
  };

  final IDeviceModuleRegistry _modules;

  RouteManager(this._modules) {
    for (final x in _modules.metaModules.entries) {
      _routes[AppRoutes.makeDeviceScreenRoute(x.key)] = (context) => _makeDeviceDetailsScreenBuilder(context, x.value);
    }
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    } else {
      return MaterialPageRoute(builder: (_) => const DevicesScreen(), settings: settings);
    }
  }

  Widget _makeDeviceDetailsScreenBuilder(BuildContext context, DeviceModuleMetadata meta) {
    return meta.detailsViewBuilder(context);
  }
}
