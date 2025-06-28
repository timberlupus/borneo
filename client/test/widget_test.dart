import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Simple widget test', (WidgetTester tester) async {
    // Build a simple MaterialApp for testing
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Text('Test App'))));

    // Verify the text is found
    expect(find.text('Test App'), findsOneWidget);
  });
}
