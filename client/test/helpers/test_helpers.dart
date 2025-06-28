import 'package:flutter/material.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void pumpWidget(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(createTestWidget(widget));
}
