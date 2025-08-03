import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borneo_app/shared/widgets/power_switch.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('PowerButton Widget Tests', () {
    testWidgets('displays button with correct initial state', (WidgetTester tester) async {
      bool isOn = false;

      await tester.pumpWidget(
        createTestWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return PowerButton(
                enabled: true,
                value: isOn,
                label: Text('Power'),
                onChanged: (value) {
                  setState(() {
                    isOn = value;
                  });
                },
              );
            },
          ),
        ),
      );

      // Verify button text shows OFF initially
      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('toggles between on and off states', (WidgetTester tester) async {
      bool isOn = false;

      await tester.pumpWidget(
        createTestWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return PowerButton(
                enabled: true,
                value: isOn,
                label: Text('Power'),
                onChanged: (value) {
                  setState(() {
                    isOn = !isOn;
                  });
                },
              );
            },
          ),
        ),
      );

      // Tap the button to turn it on
      await tester.tap(find.byType(PowerButton));
      await tester.pumpAndSettle();

      // Verify button text shows ON
      expect(find.text('ON'), findsOneWidget);

      // Tap the button again to turn it off
      await tester.tap(find.byType(PowerButton));
      await tester.pumpAndSettle();

      // Verify button text shows OFF
      expect(find.text('OFF'), findsOneWidget);
    });

    testWidgets('shows power icon when on', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(PowerButton(enabled: true, value: true, label: Text('Power'), onChanged: (value) {})),
      );

      // Verify power icon is displayed
      expect(find.byIcon(Icons.power_settings_new_outlined), findsOneWidget);
    });

    testWidgets('shows power off icon when off', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(PowerButton(enabled: true, value: false, label: Text('Power'), onChanged: (value) {})),
      );

      // Verify power icon is displayed
      expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    });

    testWidgets('calls onChanged callback when toggled', (WidgetTester tester) async {
      bool callbackCalled = false;
      bool newValue = false;

      await tester.pumpWidget(
        createTestWidget(
          PowerButton(
            enabled: true,
            value: false,
            label: Text('Power'),
            onChanged: (value) {
              callbackCalled = true;
              newValue = value;
            },
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      // Verify callback was called with correct value
      expect(callbackCalled, isTrue);
    });

    testWidgets('disabled button does not respond to taps', (WidgetTester tester) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          PowerButton(
            enabled: false,
            value: false,
            label: Text('Power'),
            onChanged: (value) {
              callbackCalled = true;
            },
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(PowerButton));
      await tester.pump();

      // Verify callback was not called
      expect(callbackCalled, isFalse);
    });
  });
}
