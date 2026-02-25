import 'dart:io';

import 'package:borneo_app/core/infrastructure/logging.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/core/services/device_exception_handler.dart';
import 'package:borneo_app/core/services/devices/ble_provisioner.dart';
import 'package:borneo_app/core/services/devices/device_module_harvesters.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/devices/mdns.dart';
import 'package:borneo_app/core/services/devices/static_modular_driver_registry.dart';
import 'package:borneo_kernel/kernel.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_gettext/gettext/gettext.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart' as provider;
import 'package:borneo_app/core/services/platform_service.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:window_size/window_size.dart';

import 'app/app.dart';
import 'core/config/language_config.dart';
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

/// Builds the root app widget with all service providers wired up.
///
/// All parameters are optional; when omitted the production implementations
/// are used.  Pass explicit values to inject test-friendly alternatives
/// (e.g. an in-memory [Database] created with `databaseFactoryMemory`).
Future<Widget> buildAppWidget({
  Database? database,
  SharedPreferences? sharedPreferences,
  EventBus? eventBus,
  IDeviceModuleRegistry? deviceModuleRegistry,
  IMdnsProvider? mdnsProvider,
}) async {
  final db = database ?? await openDatabase();
  final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
  final bus = eventBus ?? EventBus();
  final registry = deviceModuleRegistry ?? DeviceModuleRegistry(StaticDeviceModuleHarvester());

  // Read locale synchronously from the already-loaded SharedPreferences so the
  // first frame uses the correct locale instead of the system locale.
  final localeStr = prefs.getString('app.locale');
  final initialLocale = localeStr != null ? LanguageConfig.languageCodeToLocale(localeStr) : null;

  final List<SingleChildWidget> providers = [
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

    // DeviceExceptionHandler
    provider.ProxyProvider<Logger, DeviceExceptionHandler>(
      update: (_, t, r) => r ?? DeviceExceptionHandler(logger: t),
      lazy: true,
    ),

    // mDns provider
    provider.Provider<IMdnsProvider>(create: (_) => mdnsProvider ?? NsdMdnsProvider(), lazy: true),

    // IDeviceModuleRegistry
    provider.Provider<IDeviceModuleRegistry>(create: (_) => registry, lazy: true),

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

    // PlatformService (used by various components to make platform checks testable)
    provider.Provider<PlatformService>(create: (_) => PlatformServiceImpl(), lazy: false),

    // EventBus
    provider.Provider<EventBus>(create: (_) => bus, lazy: false),

    // SharedPreferences
    provider.Provider<SharedPreferences>(create: (_) => prefs, lazy: false),

    // IBleProvisioner
    provider.ProxyProvider<Logger, IBleProvisioner>(update: (_, logger, prev) => prev ?? BleProvisioner(), lazy: true),
  ];

  return provider.MultiProvider(
    providers: providers,
    child: BorneoApp(initialLocale: initialLocale),
  );
}

Future<void> main() async {
  // Ensure binding initialization and app startup occur in the SAME zone as runApp
  runZonedGuarded(
    () async {
      WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      final db = await openDatabase();

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Get current screen information
        final screen = await getCurrentScreen();
        if (screen != null) {
          final screenSize = screen.visibleFrame.size;
          final screenWidth = screenSize.width;
          final screenHeight = screenSize.height;

          // Define portrait aspect ratio (width/height ≈ 0.4615)
          const double aspectRatio = 9 / 19.5;

          // Calculate window height: set to 80% of screen height, clamped between 600 and 960
          double height = screenHeight * 0.8;
          if (height > 960) height = 960; // Upper limit
          if (height < 600) height = 600; // Lower limit for usability

          // Calculate width based on aspect ratio
          double width = height * aspectRatio;

          // Ensure width does not exceed 90% of screen width
          if (width > screenWidth * 0.9) {
            width = screenWidth * 0.9;
            height = width / aspectRatio; // Recalculate height to maintain ratio
          }

          // Set window size and position
          setWindowMinSize(Size(width * 0.5, height * 0.5)); // Min size is 50% of calculated
          setWindowMaxSize(Size(width, height)); // Max size is calculated value
          setWindowFrame(
            Rect.fromLTWH(
              (screenWidth - width) / 2, // Center horizontally
              (screenHeight - height) / 2, // Center vertically
              width,
              height,
            ),
          );
        } else {
          // Fallback to fixed size if screen info unavailable
          const double aspectRatio = 9 / 19.5;
          const double height = 960;
          final double width = height * aspectRatio;
          setWindowMinSize(Size(width, height));
          setWindowMaxSize(Size(width, height));
          setWindowFrame(Rect.fromLTWH(100, 100, width, height));
        }
      }

      // debugRepaintRainbowEnabled = true;
      final sharedPreferences = await SharedPreferences.getInstance();
      final eventBus = EventBus();

      runApp(await buildAppWidget(database: db, sharedPreferences: sharedPreferences, eventBus: eventBus));
    },
    (Object error, StackTrace stack) {
      _fatalErrorLogger.e(error, error: error, stackTrace: stack);
    },
  );
}
