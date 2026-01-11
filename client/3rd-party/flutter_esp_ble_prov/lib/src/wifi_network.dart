class WifiNetwork {
  final String ssid;
  final int rssi;
  final int? security;

  WifiNetwork({required this.ssid, required this.rssi, this.security});

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] as String,
      rssi: json['rssi'] as int,
      security: json['security'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'rssi': rssi,
      if (security != null) 'security': security,
    };
  }

  @override
  String toString() => 'WifiNetwork(ssid: $ssid, rssi: $rssi dBm)';
}
