import 'package:borneo_app/shared/widgets/bottom_sheet_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenericBottomSheetPicker', () {
    testWidgets('tapping an item returns the correct value and closes', (tester) async {
      String? selected;
      final entries = const [
        GenericBottomSheetPickerEntry(value: 'one', label: 'One'),
        GenericBottomSheetPickerEntry(value: 'two', label: 'Two'),
        GenericBottomSheetPickerEntry(value: 'three', label: 'Three'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      GenericBottomSheetPicker.show<String>(
                        context: ctx,
                        title: 'Select',
                        entries: entries,
                        selectedValue: 'one',
                        onValueSelected: (v) => selected = v,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // make sure the sheet contents appear
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);

      // the selected item should show a check icon
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('One'), findsOneWidget);

      // tap the second entry
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(selected, 'two');
      // bottom sheet should be gone
      expect(find.text('Select'), findsNothing);
    });

    testWidgets('initial value that is not in entries falls back to first', (tester) async {
      final entries = const [
        GenericBottomSheetPickerEntry(value: 1, label: '1'),
        GenericBottomSheetPickerEntry(value: 2, label: '2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      GenericBottomSheetPicker.show<int>(
                        context: ctx,
                        title: 'Select',
                        entries: entries,
                        selectedValue: 99, // not present
                        onValueSelected: (v) {},
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // first entry should be considered selected
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('BottomSheetPicker (legacy)', () {
    testWidgets('show uses generic picker behind the scenes', (tester) async {
      int? index;
      final items = ['a', 'b', 'c'];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      BottomSheetPicker.show(
                        context: ctx,
                        title: 'Letters',
                        items: items,
                        selectedIndex: 1,
                        onItemSelected: (i) => index = i,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Letters'), findsOneWidget);

      await tester.tap(find.text('c'));
      await tester.pumpAndSettle();

      expect(index, 2);
    });
  });
}
