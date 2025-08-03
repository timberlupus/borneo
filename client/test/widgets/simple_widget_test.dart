import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

// Simple widget for testing
class TestWidget extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const TestWidget({super.key, required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title), onTap: onTap);
  }
}

// Simple counter widget
class CounterWidget extends StatefulWidget {
  final int initialValue;
  const CounterWidget({super.key, this.initialValue = 0});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  late int _counter;

  @override
  void initState() {
    super.initState();
    _counter = widget.initialValue;
  }

  void _increment() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: $_counter'),
        ElevatedButton(onPressed: _increment, child: const Text('Increment')),
      ],
    );
  }
}

void main() {
  group('Widget Tests', () {
    testWidgets('TestWidget displays title correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const TestWidget(title: 'Test Title')));

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('TestWidget responds to taps', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(createTestWidget(TestWidget(title: 'Tap Test', onTap: () => tapped = true)));

      await tester.tap(find.text('Tap Test'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('CounterWidget displays initial value', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const CounterWidget(initialValue: 5)));

      expect(find.text('Count: 5'), findsOneWidget);
    });

    testWidgets('CounterWidget increments correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const CounterWidget()));

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('CounterWidget increments multiple times', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const CounterWidget()));

      for (var i = 1; i <= 3; i++) {
        await tester.tap(find.text('Increment'));
        await tester.pump();
        expect(find.text('Count: $i'), findsOneWidget);
      }
    });
  });
}
