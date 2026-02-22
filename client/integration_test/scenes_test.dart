import 'dart:collection';
import 'dart:io';

import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:borneo_app/main.dart' as app;

// ---------------------------------------------------------------------------
// Fake implementations for testing
// ---------------------------------------------------------------------------

class _FakeRegistry implements IDeviceModuleRegistry {
  @override
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules => UnmodifiableMapView({});
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the full app widget backed by an in-memory database, suitable for
/// integration tests that must not touch the filesystem.
Future<Widget> _buildTestApp({IDeviceModuleRegistry? registry}) async {
  // Force English locale so text-matching assertions are language-independent.
  SharedPreferences.setMockInitialValues({'app.locale': 'en_US'});
  final db = await databaseFactoryMemory.openDatabase('test_${DateTime.now().microsecondsSinceEpoch}.db');
  return app.buildAppWidget(
    database: db,
    sharedPreferences: await SharedPreferences.getInstance(),
    deviceModuleRegistry: registry ?? _FakeRegistry(),
  );
}

/// Repeatedly pumps the tester until [finder] is found or the [timeout]
/// expires.  This is more reliable than `pumpAndSettle` when the UI shows an
/// indefinite animation (e.g. a loading spinner) that would otherwise keep
/// scheduling frames.
Future<void> _waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) return;
  }
  // Final check to produce a sensible failure message
  await tester.pump();
  expect(tester.any(finder), true, reason: 'Expected $finder to appear within $timeout');
}

/// Scenes related integration tests.
void scenesTests() {
  testWidgets('Manage scenes via UI', (WidgetTester tester) async {
    await tester.pumpWidget(await _buildTestApp());
    await tester.pumpAndSettle();

    // navigate to scenes tab by tapping bottom navigation icon.  The
    // active tab may show the filled house icon, so try to tap whichever is
    // present.
    await tester.pump(const Duration(seconds: 1));
    final filled = find.byIcon(Icons.house);
    final outlined = find.byIcon(Icons.house_outlined);
    if (tester.any(outlined)) {
      await tester.tap(outlined);
    } else {
      await tester.tap(filled);
    }
    await tester.pumpAndSettle();

    // the first card corresponds to the default scene "My Home"
    await _waitFor(tester, find.byKey(const Key('scene_card_My Home')));

    // add a new scene
    await tester.tap(find.byKey(const Key('btn_add_scene')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field_scene_name')), 'Test Scene');
    await tester.pump();
    expect(find.byKey(const Key('btn_submit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_submit')));

    // give database and animations a moment
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _waitFor(tester, find.byKey(const Key('scene_card_Test Scene')), timeout: const Duration(seconds: 10));

    // switch back to the original scene by tapping its card.  After the new
    // scene is created it becomes selected and may push the old card offscreen.
    // Rather than reference the list itself we simply drag on the currently
    // visible card (the one for the test scene) until the "My Home" card
    // becomes built.
    const targetKey = Key('scene_card_My Home');
    // scroll the horizontal list until the old card is built
    await tester.scrollUntilVisible(find.byKey(targetKey), 500.0, scrollable: find.byKey(const Key('scene_list')));
    await tester.tap(find.byKey(targetKey));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ensure current scene indicator moved (the edit button should show on selected card)
    expect(find.byKey(const Key('btn_edit_scene_My Home')), findsOneWidget);
    expect(find.byKey(const Key('btn_edit_scene_Test Scene')), findsNothing);

    // edit the new scene
    await tester.tap(find.byKey(const Key('btn_edit_scene_Test Scene')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field_scene_name')), 'Updated Scene');
    await tester.tap(find.byKey(const Key('btn_submit')));
    await tester.pump(const Duration(milliseconds: 500));
    await _waitFor(tester, find.byKey(const Key('scene_card_Updated Scene')));

    // delete the updated scene
    await tester.tap(find.byKey(const Key('btn_edit_scene_Updated Scene')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_delete_scene')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_confirm_delete')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('scene_card_Updated Scene')), findsNothing);
  });
}
