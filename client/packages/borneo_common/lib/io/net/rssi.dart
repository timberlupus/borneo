enum RssiLevel {
  strong,
  medium,
  weak,
}

extension RssiLevelExtension on RssiLevel {
  int get minRssi => switch (this) {
        RssiLevel.strong => -50,
        RssiLevel.medium => -70,
        RssiLevel.weak => -90,
      };

  static RssiLevel fromRssi(int rssi) {
    if (rssi >= -50) return RssiLevel.strong;
    if (rssi >= -70) return RssiLevel.medium;
    return RssiLevel.weak;
  }
}
