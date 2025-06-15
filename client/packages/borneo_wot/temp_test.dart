import 'lib/utils.dart';

void main() {
  final original = DateTime.now().toUtc().toIso8601String();
  final modified = timestamp();
  print('Original: $original');
  print('Modified: $modified');
  print('Contains +00:00: ${modified.contains('+00:00')}');

  // Test the regex
  final testString = '2025-06-15T13:32:22.887141Z';
  final result = testString.replaceAll(RegExp(r'\.\d{3}Z$'), '+00:00');
  print('Test result: $result');
}
