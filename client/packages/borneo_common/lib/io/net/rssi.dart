enum RssiLevel {
  excellent,
  good,
  fair,
  poor,
}

extension RssiLevelExtension on RssiLevel {
  int get minRssi {
    switch (this) {
      case RssiLevel.excellent:
        return -30;
      case RssiLevel.good:
        return -50;
      case RssiLevel.fair:
        return -70;
      case RssiLevel.poor:
        return -90;
    }
  }

  static RssiLevel fromRssi(int rssi) {
    if (rssi >= -30) return RssiLevel.excellent;
    if (rssi >= -50) return RssiLevel.good;
    if (rssi >= -70) return RssiLevel.fair;
    return RssiLevel.poor;
  }
}
