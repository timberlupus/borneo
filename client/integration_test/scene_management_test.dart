import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:borneo_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Scene Management Integration Tests', () {
    testWidgets('scenes list loads correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scenes tab
      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify scenes screen is shown
      expect(find.text('Scenes'), findsOneWidget);

      // Check for scenes list or empty state
      final emptyState = find.text('No scenes found');
      final sceneGrid = find.byType(GridView);

      expect(
        emptyState.evaluate().isNotEmpty || sceneGrid.evaluate().isNotEmpty,
        isTrue,
        reason: 'Should show either empty state or scenes grid',
      );
    });

    testWidgets('create new scene flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scenes tab
      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle();

      // Look for add scene button
      final addButton = find.byType(FloatingActionButton);
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Verify scene creation screen
        expect(find.text('Create Scene'), findsOneWidget);

        // Test scene name input
        final nameField = find.byType(TextField);
        if (nameField.evaluate().isNotEmpty) {
          await tester.enterText(nameField.first, 'Test Scene');
          await tester.pumpAndSettle();

          // Check if name was entered
          expect(find.text('Test Scene'), findsOneWidget);
        }
      }
    });

    testWidgets('scene details navigation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scenes tab
      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle();

      // If scenes exist, test navigation to scene details
      final sceneCards = find.byType(Card);
      if (sceneCards.evaluate().isNotEmpty) {
        await tester.tap(sceneCards.first);
        await tester.pumpAndSettle();

        // Verify scene details screen is shown
        expect(find.byType(AppBar), findsOneWidget);
      }
    });

    testWidgets('scene editing functionality', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scenes tab
      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle();

      // If scenes exist, test editing
      final sceneCards = find.byType(Card);
      if (sceneCards.evaluate().isNotEmpty) {
        // Long press to enter edit mode
        await tester.longPress(sceneCards.first);
        await tester.pumpAndSettle();

        // Look for edit options
        final editButton = find.byIcon(Icons.edit);
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pumpAndSettle();

          // Verify edit screen
          expect(find.text('Edit Scene'), findsOneWidget);
        }
      }
    });

    testWidgets('scene deletion flow', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to scenes tab
      await tester.tap(find.byIcon(Icons.photo_library));
      await tester.pumpAndSettle();

      // If scenes exist, test deletion
      final sceneCards = find.byType(Card);
      if (sceneCards.evaluate().isNotEmpty) {
        // Long press to enter selection mode
        await tester.longPress(sceneCards.first);
        await tester.pumpAndSettle();

        // Look for delete button
        final deleteButton = find.byIcon(Icons.delete);
        if (deleteButton.evaluate().isNotEmpty) {
          await tester.tap(deleteButton);
          await tester.pumpAndSettle();

          // Verify confirmation dialog
          expect(find.text('Delete'), findsOneWidget);
        }
      }
    });
  });
}
