import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:borneo_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Borneo App Integration Tests', () {
    testWidgets('app starts successfully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('main screen navigation works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify bottom navigation is present
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Test navigation between tabs
      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
    });

    testWidgets('device discovery flow works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to devices tab
      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle();

      // Look for device discovery button or add device button
      final addDeviceButton = find.byType(FloatingActionButton);
      if (addDeviceButton.evaluate().isNotEmpty) {
        await tester.tap(addDeviceButton);
        await tester.pumpAndSettle();

        // Verify device discovery screen is shown
        expect(find.text('Discover Devices'), findsOneWidget);
      }
    });

    testWidgets('scene management flow works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scenes tab
      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle();

      // Verify scenes screen is shown
      expect(find.text('Scenes'), findsOneWidget);

      // Look for add scene button
      final addSceneButton = find.byType(FloatingActionButton);
      if (addSceneButton.evaluate().isNotEmpty) {
        await tester.tap(addSceneButton);
        await tester.pumpAndSettle();

        // Verify scene creation screen is shown
        expect(find.text('Create Scene'), findsOneWidget);
      }
    });

    testWidgets('settings screen loads correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to settings tab
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // Verify settings screen is shown
      expect(find.text('Settings'), findsOneWidget);

      // Check for common settings options
      expect(find.text('App Settings'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });
  });
}
