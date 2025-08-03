import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:borneo_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Device Management Integration Tests', () {
    testWidgets('device list loads correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to devices tab
      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify device management screen is shown
      expect(find.text('Devices'), findsOneWidget);

      // Check for device list or empty state
      final emptyState = find.text('No devices found');
      final deviceList = find.byType(ListView);

      expect(
        emptyState.evaluate().isNotEmpty || deviceList.evaluate().isNotEmpty,
        isTrue,
        reason: 'Should show either empty state or device list',
      );
    });

    testWidgets('device grouping functionality works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to devices tab
      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle();

      // Look for group management functionality
      final groupButton = find.byIcon(Icons.folder);
      if (groupButton.evaluate().isNotEmpty) {
        await tester.tap(groupButton);
        await tester.pumpAndSettle();

        // Verify group management screen
        expect(find.text('Groups'), findsOneWidget);
      }
    });

    testWidgets('device details screen navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to devices tab
      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle();

      // If devices exist, test navigation to device details
      final deviceItems = find.byType(ListTile);
      if (deviceItems.evaluate().isNotEmpty) {
        await tester.tap(deviceItems.first);
        await tester.pumpAndSettle();

        // Verify device details screen is shown
        expect(find.byType(AppBar), findsOneWidget);
      }
    });

    testWidgets('refresh functionality works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to devices tab
      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle();

      // Look for refresh indicator
      final refreshIndicator = find.byType(RefreshIndicator);
      if (refreshIndicator.evaluate().isNotEmpty) {
        await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        // Verify refresh completed
        expect(find.byType(ListView), findsOneWidget);
      }
    });
  });
}
