import 'dart:typed_data';

sealed class DiscoveredDevice {
  final String host;
  final int? port;
  final String? name;

  const DiscoveredDevice({
    required this.host,
    required this.port,
    this.name,
  });

  @override
  String toString() {
    return 'DiscoveredDevice(name: `$name`, host: `$host`, port: `${port ?? 'N/A'}`)';
  }
}

class MdnsDiscoveredDevice extends DiscoveredDevice {
  final Map<String, Uint8List?>? txt;
  final String? serviceType;
  const MdnsDiscoveredDevice({
    required super.host,
    super.port,
    super.name,
    this.txt,
    this.serviceType,
  });
}

class BleDiscoveredDevice extends DiscoveredDevice {
  const BleDiscoveredDevice({
    required super.host,
    super.port,
    super.name,
    //... TODO
  });
}
