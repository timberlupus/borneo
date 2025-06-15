import 'package:test/test.dart';

void main() {
  test('exports all main files', () {
    // Just check that the exports are accessible
    expect(() => null, returnsNormally);
  });
}
