import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Widget createTestWidgetWithProvider(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void pumpWidget(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(createTestWidget(widget));
}

void pumpWidgetWithProvider(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(createTestWidgetWithProvider(widget));
}

// Test utilities for view models
class TestUtils {
  static Future<void> waitForWidget(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  static Future<void> waitForAsync(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }
}
