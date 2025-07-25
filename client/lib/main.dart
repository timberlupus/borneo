import 'package:borneo_app/core/infrastructure/logging.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/core/services/devices/device_module_harvesters.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/devices/mdns.dart';
import 'package:borneo_app/core/services/devices/static_modular_driver_registry.dart';
import 'package:borneo_kernel/kernel.dart';
import 'package:borneo_kernel_abstractions/idriver_registry.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:borneo_kernel_abstractions/mdns.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_gettext/gettext/gettext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:async';

import 'package:sembast/sembast.dart';

import 'app/app.dart';
import 'routes/route_manager.dart';

import 'core/services/db.dart';
import 'core/services/local_service.dart';

Future<Database> openDatabase() async {
  final appDir = await getApplicationDocumentsDirectory();
  await appDir.create(recursive: true);

  final dbProvider = DBProvider(appDir.path);
  await dbProvider.initialize();

  if (await dbProvider.isExisted()) {
    // For Debug only!
    // await dbProvider.delete();
  }

  return await dbProvider.open();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await openDatabase();
  // debugRepaintRainbowEnabled = true;
  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          child: provider.MultiProvider(
            providers: [
              // Logger
              provider.Provider<Logger>(
                create: (_) => createLogger(),
                lazy: false,
                dispose: (_, logger) {
                  logger.close();
                },
              ),

              // IClock
              provider.Provider<IClock>(create: (_) => DefaultClock()),

              // DB
              provider.Provider<Database>(
                create: (_) => db,
                lazy: false,
                dispose: (_, db) {
                  db.close();
                },
              ),

              // mDns provider
              provider.Provider<IMdnsProvider>(create: (_) => NsdMdnsProvider(), lazy: true),

              // IDeviceModuleRegistry
              provider.Provider<IDeviceModuleRegistry>(
                create: (_) => DeviceModuleRegistry(StaticDeviceModuleHarvester()),
                lazy: true,
              ),

              // RouteManager
              provider.ProxyProvider<IDeviceModuleRegistry, RouteManager>(
                update: (_, reg, rm) => rm ?? RouteManager(reg),
                lazy: true,
              ),

              // IDriverRegistry
              provider.ProxyProvider<IDeviceModuleRegistry, IDriverRegistry>(
                update: (_, reg, smdr) => smdr ?? StaticModularDriverRegistry(reg),
                lazy: true,
              ),

              // IKernel
              provider.ProxyProvider3<Logger, IDriverRegistry, IMdnsProvider, IKernel>(
                update: (_, logger, driverReg, nsdMdns, kernel) =>
                    kernel ?? DefaultKernel(logger, driverReg, mdnsProvider: nsdMdns),
                dispose: (context, kernel) => kernel.dispose(),
                lazy: true,
              ),

              // LocaleService
              provider.Provider<LocaleService>(create: (_) => AppLocaleService(), lazy: false),
            ],
            child: BorneoApp(),
          ),
        ),
      );
    },
    (error, stack) {
      print('Uncaught async error: $error\n$stack');
      // 如果有 logger，可以用 logger?.e('Uncaught async error: $error\n$stack');
    },
  );
}
