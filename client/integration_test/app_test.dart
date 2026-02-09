import 'package:borneo_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows main screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(BorneoApp());

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify that the app has started and shows the main screen
    // Check for a basic widget that should be present
    expect(find.byType(MaterialApp), findsOneWidget);

    // You can add more specific checks here, for example:
    // expect(find.text('Borneo'), findsOneWidget); // If there's a title
    // or check for specific screens/widgets
  });
}