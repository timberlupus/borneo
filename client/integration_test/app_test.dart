import 'dart:collection';
import 'dart:io';

import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sembast/sembast_memory.dart';
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows main screen', (WidgetTester tester) async {
    await tester.pumpWidget(await _buildTestApp());
    await tester.pumpAndSettle();

    // Verify that the app has started and shows the main screen
    expect(find.byType(MaterialApp), findsOneWidget);
  }, skip: !Platform.isLinux && !Platform.isWindows);

  testWidgets('Manage device groups via UI', (WidgetTester tester) async {
    await tester.pumpWidget(await _buildTestApp());
    await tester.pumpAndSettle();

    // navigate to devices tab by tapping bottom navigation icon
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.device_hub_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.device_hub_outlined));
    await tester.pumpAndSettle();

    // open add menu and select Add Devices Group
    await tester.tap(find.byIcon(Icons.add_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu_item_add_group')));
    await tester.pumpAndSettle();

    // fill in group name and submit
    await tester.enterText(find.byKey(const Key('field_group_name')), 'Test Group');
    await tester.tap(find.byKey(const Key('btn_submit')));
    // Give DB write + EventBus async delivery + reload time to complete.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // verify group shows up in list
    expect(find.text('Test Group'), findsOneWidget);

    // edit the group
    await tester.tap(find.byKey(const Key('btn_edit_group_Test Group')));
    await tester.pumpAndSettle();

    // change name and submit
    await tester.enterText(find.byKey(const Key('field_group_name')), 'Updated Group');
    await tester.tap(find.byKey(const Key('btn_submit')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Updated Group'), findsOneWidget);

    // delete the group
    await tester.tap(find.byKey(const Key('btn_edit_group_Updated Group')));
    await tester.pumpAndSettle();

    // tap delete icon in app bar
    await tester.tap(find.byKey(const Key('btn_delete_group')));
    await tester.pumpAndSettle();

    // confirm deletion
    await tester.tap(find.byKey(const Key('btn_confirm_delete')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // group should no longer be present
    expect(find.text('Updated Group'), findsNothing);
  });
}
