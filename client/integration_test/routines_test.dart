import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:borneo_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Routines Integration Tests', () {
    testWidgets('routines list loads correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to routines tab
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify routines screen is shown
      expect(find.text('Routines'), findsOneWidget);

      // Check for routines list or empty state
      final emptyState = find.text('No routines found');
      final routineList = find.byType(ListView);

      expect(
        emptyState.evaluate().isNotEmpty || routineList.evaluate().isNotEmpty,
        isTrue,
        reason: 'Should show either empty state or routines list',
      );
    });

    testWidgets('routine activation flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to routines tab
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      // If routines exist, test activation
      final routineCards = find.byType(Card);
      if (routineCards.evaluate().isNotEmpty) {
        // Look for activation switch
        final switches = find.byType(Switch);
        if (switches.evaluate().isNotEmpty) {
          final initialState = tester.widget<Switch>(switches.first).value;

          await tester.tap(switches.first);
          await tester.pumpAndSettle();

          // Verify switch state changed
          final newState = tester.widget<Switch>(switches.first).value;
          expect(newState, isNot(initialState));
        }
      }
    });

    testWidgets('routine execution flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to routines tab
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      // Look for manual execution button
      final executeButtons = find.byIcon(Icons.play_arrow);
      if (executeButtons.evaluate().isNotEmpty) {
        await tester.tap(executeButtons.first);
        await tester.pumpAndSettle();

        // Verify confirmation or execution feedback
        expect(
          find.text('Executing').evaluate().isNotEmpty ||
              find.text('Started').evaluate().isNotEmpty ||
              find.byType(SnackBar).evaluate().isNotEmpty,
          isTrue,
        );
      }
    });

    testWidgets('routine details navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to routines tab
      await tester.tap(find.byIcon(Icons.schedule));
      await tester.pumpAndSettle();

      // If routines exist, test navigation to details
      final routineCards = find.byType(Card);
      if (routineCards.evaluate().isNotEmpty) {
        await tester.tap(routineCards.first);
        await tester.pumpAndSettle();

        // Verify routine details screen is shown
        expect(find.byType(AppBar), findsOneWidget);
      }
    });
  });
}
