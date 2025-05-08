import 'dart:typed_data';

double convertToFloat32(double value) {
  final float32List = Float32List(1);
  float32List[0] = value;
  return float32List[0];
}

bool isValidFloat32(double value) {
  if (value.isNaN || value.isInfinite) {
    return false;
  }
  const float32Max = 3.4e38;
  return value.abs() <= float32Max;
}
