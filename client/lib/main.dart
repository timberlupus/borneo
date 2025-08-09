import 'dart:io';

import 'package:borneo_app/core/infrastructure/logging.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/core/services/device_exception_handler.dart';
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
import 'package:window_size/window_size.dart';

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

final _fatalErrorLogger = createLogger();

Future<void> main() async {
  // Ensure binding initialization and app startup occur in the SAME zone as runApp
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final db = await openDatabase();

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        const double aspectRatio = 9 / 19.5;
        const double height = 960;
        final double width = height * aspectRatio;
        setWindowMinSize(Size(width, height));
        setWindowMaxSize(Size(width, height));
        setWindowFrame(Rect.fromLTWH(100, 100, width, height));
      }

      // debugRepaintRainbowEnabled = true;
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

              // DeviceExceptionhandler
              provider.ProxyProvider<Logger, DeviceExceptionHandler>(
                update: (_, t, r) => r ?? DeviceExceptionHandler(logger: t),
                lazy: true,
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
              provider.Provider<ILocaleService>(create: (_) => AppLocaleService(), lazy: false),
            ],
            child: BorneoApp(),
          ),
        ),
      );
    },
    (Object error, StackTrace stack) {
      _fatalErrorLogger.e(error, error: error, stackTrace: stack);
    },
  );
}
