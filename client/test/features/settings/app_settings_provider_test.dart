import 'package:borneo_app/core/events/app_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_bus/event_bus.dart';

import 'package:borneo_app/features/settings/providers/app_settings_provider.dart';
import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/core/providers.dart';

const _testBrightnessKey = 'app.brightness';
const _testLocaleKey = 'app.locale';

class _FakeLocaleService implements ILocaleService {
  String _unit = 'C';

  @override
  Future<void> initialize() async {}

  @override
  String get temperatureUnitText => _unit == 'F' ? '°F' : '°C';

  @override
  double convertTemperatureValue(double celsius) => celsius;

  @override
  String get temperatureUnit => _unit;

  @override
  Future<void> setTemperatureUnit(String unit) async {
    _unit = unit;
  }
}

void main() {
  // required because the notifier uses WidgetsBinding to access
  // platform brightness/locale during initialization
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsNotifier', () {
    late ProviderContainer container;
    late SharedPreferences prefs;
    late _FakeLocaleService fakeLocale;
    late EventBus bus;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeLocale = _FakeLocaleService();
      bus = EventBus();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localeServiceProvider.overrideWithValue(fakeLocale),
          eventBusProvider.overrideWithValue(bus),
        ],
      );

      // force initialization to complete so later writes can read `state.value`
      await container.read(appSettingsProvider.future);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state loads defaults', () async {
      final state = await container.read(appSettingsProvider.future);
      expect(state.themeMode, isNotNull);
      expect(state.locale, isNotNull);
      expect(state.temperatureUnit, 'C');
    });

    test('changeBrightness updates state and preferences', () async {
      final notifier = container.read(appSettingsProvider.notifier);
      // listen for bus event
      bus
          .on<ThemeChangedEvent>()
          .take(1)
          .listen(
            expectAsync1((evt) {
              expect(evt.themeMode, ThemeMode.dark);
            }),
          );

      await notifier.changeBrightness(ThemeMode.dark);
      final state = container.read(appSettingsProvider).value!;
      expect(state.themeMode, ThemeMode.dark);
      expect(prefs.getInt(_testBrightnessKey), ThemeMode.dark.index);
    });

    test('changeLocale updates state and preferences', () async {
      final notifier = container.read(appSettingsProvider.notifier);
      final newLocale = const Locale('es', '');
      bus
          .on<AppLocaleChangedEvent>()
          .take(1)
          .listen(
            expectAsync1((evt) {
              expect(evt.locale, newLocale);
            }),
          );

      await notifier.changeLocale(newLocale);
      final state = container.read(appSettingsProvider).value!;
      expect(state.locale, newLocale);
      expect(prefs.getString(_testLocaleKey), 'es');
    });

    test('changeTemperatureUnit updates state and locale service', () async {
      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.changeTemperatureUnit('F');
      final state = container.read(appSettingsProvider).value!;
      expect(state.temperatureUnit, 'F');
      expect(fakeLocale.temperatureUnit, 'F');
    });
  });
}
