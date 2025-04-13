import 'package:borneo_app/views/main_screen.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations_delegate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes/route_manager.dart';
import 'services/blob_manager.dart';
import 'services/device_manager.dart';
import 'services/group_manager.dart';
import 'services/routine_manager.dart';
import 'services/scene_manager.dart';
import 'theme/app_theme.dart';

const _kSupportedLocales = [Locale('en'), Locale('zh', 'CN')];

class BorneoApp extends StatelessWidget {
  final EventBus _globalEventBus = EventBus();

  BorneoApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      // Global event bus
      Provider<EventBus>(create: (_) => _globalEventBus),

      // BlobManager
      Provider<IBlobManager>(create: (_) => FlutterAppBlobManager()),
    ],

    // Main screen
    child: MaterialApp(
      title: 'Borneo-IoT',
      theme: BorneoTheme(Theme.of(context).textTheme).light(),
      darkTheme: BorneoTheme(Theme.of(context).textTheme).dark(),
      themeMode: ThemeMode.dark,
      onGenerateRoute: context.read<RouteManager>().onGenerateRoute,
      supportedLocales: _kSupportedLocales,
      localizationsDelegates: [
        GettextLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        final gt = GettextLocalizations.of(context);
        return MultiProvider(
          providers: [
            // Here >>> register all providers that need to access the gettext interface <<<
            // SceneManager
            Provider<SceneManager>(
              create:
                  (context) => SceneManager(
                    gt,
                    context.read<Database>(),
                    context.read<EventBus>(),
                    context.read<IBlobManager>(),
                    logger: context.read<Logger>(),
                  ),
            ),

            // GroupManager
            Provider<GroupManager>(
              create:
                  (context) => GroupManager(
                    context.read<Logger>(),
                    context.read<EventBus>(),
                    context.read<Database>(),
                    context.read<SceneManager>(),
                  ),
            ),

            // DeviceManager
            Provider<DeviceManager>(
              create:
                  (context) => DeviceManager(
                    context.read<Logger>(),
                    context.read<Database>(),
                    context.read<IKernel>(),
                    context.read<EventBus>(),
                    context.read<SceneManager>(),
                    context.read<GroupManager>(),
                  ),
              dispose: (context, dm) => dm.dispose(),
            ),

            // RoutineManager
            Provider<RoutineManager>(
              create:
                  (context) => RoutineManager(
                    context.read<EventBus>(),
                    context.read<Database>(),
                    context.read<DeviceManager>(),
                    logger: context.read<Logger>(),
                  ),
              dispose: (context, dm) => dm.dispose(),
            ),
          ],
          child: child,
        );
      },
      home: MainScreen(),
    ),
  );
}
