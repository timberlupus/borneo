import 'package:test/test.dart';
import 'package:borneo_common/utils/disposable.dart';

class TestDisposable implements IDisposable {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  group('using', () {
    test('should call dispose after action', () {
      final resource = TestDisposable();
      final result = using(resource, (r) {
        expect(r.disposed, isFalse);
        return 42;
      });
      expect(result, 42);
      expect(resource.disposed, isTrue);
    });
  });
}
