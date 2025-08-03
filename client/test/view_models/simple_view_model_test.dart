import 'package:flutter_test/flutter_test.dart';

// Simple view model for testing
class SimpleViewModel {
  String _title = '';
  int _counter = 0;
  bool _isLoading = false;

  String get title => _title;
  int get counter => _counter;
  bool get isLoading => _isLoading;

  void updateTitle(String newTitle) {
    _title = newTitle;
  }

  void increment() {
    _counter++;
  }

  void decrement() {
    _counter--;
  }

  void reset() {
    _counter = 0;
    _title = '';
  }

  Future<void> loadData() async {
    _isLoading = true;
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoading = false;
    _counter = 42;
    _title = 'Loaded';
  }

  bool get hasData => _title.isNotEmpty && _counter > 0;
}

void main() {
  group('SimpleViewModel Tests', () {
    late SimpleViewModel viewModel;

    setUp(() {
      viewModel = SimpleViewModel();
    });

    test('initial state is correct', () {
      expect(viewModel.title, isEmpty);
      expect(viewModel.counter, 0);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasData, isFalse);
    });

    test('updateTitle updates title correctly', () {
      viewModel.updateTitle('New Title');
      expect(viewModel.title, 'New Title');
    });

    test('increment increases counter by 1', () {
      viewModel.increment();
      expect(viewModel.counter, 1);
    });

    test('decrement decreases counter by 1', () {
      viewModel.increment(); // First increment to 1
      viewModel.decrement();
      expect(viewModel.counter, 0);
    });

    test('reset clears all data', () {
      viewModel.updateTitle('Test');
      viewModel.increment();
      viewModel.increment();

      viewModel.reset();

      expect(viewModel.title, isEmpty);
      expect(viewModel.counter, 0);
    });

    test('hasData returns false when no data', () {
      expect(viewModel.hasData, isFalse);
    });

    test('hasData returns true when data exists', () {
      viewModel.updateTitle('Test');
      viewModel.increment();
      expect(viewModel.hasData, isTrue);
    });

    group('Async operations', () {
      test('loadData sets loading state', () async {
        final future = viewModel.loadData();
        expect(viewModel.isLoading, isTrue);

        await future;
        expect(viewModel.isLoading, isFalse);
      });

      test('loadData updates data correctly', () async {
        await viewModel.loadData();

        expect(viewModel.counter, 42);
        expect(viewModel.title, 'Loaded');
        expect(viewModel.hasData, isTrue);
      });

      test('loadData can be awaited', () async {
        await viewModel.loadData();
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('Counter operations', () {
      test('multiple increments work correctly', () {
        for (var i = 1; i <= 5; i++) {
          viewModel.increment();
          expect(viewModel.counter, i);
        }
      });

      test('negative counter values work', () {
        viewModel.decrement();
        expect(viewModel.counter, -1);

        viewModel.decrement();
        expect(viewModel.counter, -2);
      });

      test('mixed increment and decrement operations', () {
        viewModel.increment(); // 1
        viewModel.increment(); // 2
        viewModel.decrement(); // 1
        viewModel.increment(); // 2
        viewModel.decrement(); // 1

        expect(viewModel.counter, 1);
      });
    });
  });
}
