import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:borneo_app/features/my/providers/my_provider.dart';
import '../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MyViewModel provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: [myViewModelProvider.overrideWithValue(MyViewModel(gt: FakeGettext()))]);
    });

    tearDown(() {
      container.dispose();
    });

    test('override supplies instance', () {
      final vm = container.read(myViewModelProvider);
      expect(vm, isA<MyViewModel>());
      // underlying class has no state; just ensure it doesn't throw.
      vm.notifyAppError('test');
    });
  });
}
