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

// bring in other test suites so this file serves as the aggregate entry point
import 'device_group_test.dart' as device_group_test;
import 'scenes_test.dart' as scenes_test;

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows main screen', (WidgetTester tester) async {
    await tester.pumpWidget(await _buildTestApp());
    await tester.pumpAndSettle();

    // Verify that the app has started and shows the main screen
    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: !Platform.isLinux && !Platform.isWindows);

  // delegate additional tests to other files
  device_group_test.deviceGroupTests();
  scenes_test.scenesTests();
}
