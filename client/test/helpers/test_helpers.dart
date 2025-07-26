import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void pumpWidget(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(createTestWidget(widget));
}
