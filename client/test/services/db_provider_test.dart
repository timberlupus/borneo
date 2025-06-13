import 'package:borneo_app/core/services/db.dart';
import 'package:test/test.dart';

void main() {
  group('DBProvider Tests', () {
    final db = DBProvider("./app_test");

    setUp(() async {
      await db.initialize();
    });

    test('Should be initialized', () {
      expect(db.isInitialized, true);
    });
  });
}
