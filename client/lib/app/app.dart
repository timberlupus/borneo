import 'dart:async';
import 'package:borneo_app/core/events/app_events.dart';
import 'package:borneo_app/core/services/default_app_notification_service.dart';
import 'package:borneo_app/core/services/i_app_notification_service.dart';
import 'package:borneo_app/main/views/main_screen.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations_delegate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:toastification/toastification.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/route_manager.dart';
import '../core/services/blob_manager.dart';
import '../core/services/device_manager.dart';
import '../core/services/group_manager.dart';
import '../core/services/routine_manager.dart';
import '../core/services/scene_manager.dart';
import 'app_theme.dart';

const kSupportedLocales = [Locale('en', 'US'), Locale('zh', 'CN')];

class BorneoApp extends StatefulWidget {
  final EventBus _globalEventBus = EventBus();
  BorneoApp({super.key});

  @override
  State<BorneoApp> createState() => _BorneoAppState();
}

class _BorneoAppState extends State<BorneoApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  late StreamSubscription _localeSub;
  late StreamSubscription _themeSub;

  @override
  void initState() {
    super.initState();
    _loadThemeMode().then((mode) => setState(() => _themeMode = mode));
    _loadLocale().then((loc) => setState(() => _locale = loc));
    _localeSub = widget._globalEventBus.on<AppLocaleChangedEvent>().listen((event) {
      setState(() {
        _locale = event.locale;
      });
    });
    _themeSub = widget._globalEventBus.on<ThemeChangedEvent>().listen((event) {
      setState(() {
        _themeMode = event.themeMode;
      });
    });
  }

  @override
  void dispose() {
    _localeSub.cancel();
    _themeSub.cancel();
    super.dispose();
  }

  Future<ThemeMode> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('app.brightness');
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      return ThemeMode.values[idx];
    }
    return ThemeMode.system;
  }

  Future<Locale?> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeStr = prefs.getString('app.locale');
    return switch (localeStr) {
      'zh_CN' => const Locale('zh', 'CN'),
      'en_US' => const Locale('en', 'US'),
      _ => const Locale('en', 'US'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<EventBus>(create: (_) => widget._globalEventBus),
        Provider<IBlobManager>(create: (_) => FlutterAppBlobManager()),
      ],
      child: ToastificationWrapper(
        config: ToastificationConfig(animationDuration: Duration(milliseconds: 300), maxToastLimit: 3),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              title: 'Borneo-IoT',
              theme: BorneoTheme(Theme.of(context).textTheme).light(),
              darkTheme: BorneoTheme(Theme.of(context).textTheme).dark(),
              themeMode: _themeMode,
              locale: _locale,
              supportedLocales: kSupportedLocales,
              onGenerateRoute: context.read<RouteManager>().onGenerateRoute,
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
                    Provider<IAppNotificationService>(create: (context) => DefaultAppNotificationService()),
                    // Here >>> register all providers that need to access the gettext interface <<<
                    // SceneManager
                    Provider<SceneManager>(
                      create: (context) => SceneManager(
                        gt,
                        context.read<Database>(),
                        context.read<EventBus>(),
                        context.read<IBlobManager>(),
                        logger: context.read<Logger>(),
                      ),
                    ),

                    // GroupManager
                    Provider<GroupManager>(
                      create: (context) => GroupManager(
                        context.read<Logger>(),
                        context.read<EventBus>(),
                        context.read<Database>(),
                        context.read<SceneManager>(),
                      ),
                    ),

                    // DeviceManager
                    Provider<DeviceManager>(
                      create: (context) => DeviceManager(
                        context.read<Database>(),
                        context.read<IKernel>(),
                        context.read<EventBus>(),
                        context.read<SceneManager>(),
                        context.read<GroupManager>(),
                        logger: context.read<Logger>(),
                      ),
                      dispose: (context, dm) => dm.dispose(),
                    ),

                    // RoutineManager
                    Provider<RoutineManager>(
                      create: (context) => RoutineManager(
                        context.read<EventBus>(),
                        context.read<Database>(),
                        context.read<DeviceManager>(),
                        logger: context.read<Logger>(),
                      ),
                      dispose: (context, rm) => rm.dispose(),
                    ),
                  ],
                  child: child,
                );
              },
              home: MainScreen(),
            );
          },
        ),
      ),
    );
  }
}
