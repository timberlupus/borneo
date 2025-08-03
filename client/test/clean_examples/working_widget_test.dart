import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple test widget
class TestCounterWidget extends StatefulWidget {
  const TestCounterWidget({super.key});

  @override
  State<TestCounterWidget> createState() => _TestCounterWidgetState();
}

class _TestCounterWidgetState extends State<TestCounterWidget> {
  int _counter = 0;

  void _increment() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('Count: $_counter'),
            ElevatedButton(onPressed: _increment, child: const Text('Increment')),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Widget Test Examples', () {
    testWidgets('Counter test', (WidgetTester tester) async {
      await tester.pumpWidget(const TestCounterWidget());

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('Button exists test', (WidgetTester tester) async {
      await tester.pumpWidget(const TestCounterWidget());

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Increment'), findsOneWidget);
    });
  });
}
