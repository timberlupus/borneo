import 'dart:io';

/// Network interface helper class
class NetworkInterfaceHelper {
  /// Infers the corresponding network interface address based on the IP address
  static Future<String?> inferNetworkInterface(String deviceIp) async {
    try {
      final deviceAddress = InternetAddress.tryParse(deviceIp);
      if (deviceAddress == null) return null;

      final interfaces = await NetworkInterface.list(includeLoopback: false, includeLinkLocal: false);

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (_isInSameNetwork(deviceAddress, addr)) {
            return addr.address;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Determines whether two IP addresses are on the same network
  static bool _isInSameNetwork(InternetAddress ip1, InternetAddress ip2) {
    if (ip1.type != ip2.type) return false;

    if (ip1.type == InternetAddressType.IPv4) {
      return _isInSameSubnetIPv4(ip1.address, ip2.address);
    } else {
      return _isInSameSubnetIPv6(ip1.address, ip2.address);
    }
  }

  /// IPv4 subnet check (simple implementation: check the first two octets)
  static bool _isInSameSubnetIPv4(String ip1, String ip2) {
    final parts1 = ip1.split('.');
    final parts2 = ip2.split('.');

    if (parts1.length != 4 || parts2.length != 4) return false;

    // Check if the first two octets are the same (/16 subnet)
    return parts1[0] == parts2[0] && parts1[1] == parts2[1];
  }

  /// IPv6 subnet check (simplified implementation)
  static bool _isInSameSubnetIPv6(String ip1, String ip2) {
    // Simplified implementation: check the prefix of the IPv6 address
    final normalized1 = ip1.toLowerCase().replaceAll(':', '');
    final normalized2 = ip2.toLowerCase().replaceAll(':', '');

    return normalized1.substring(0, 8) == normalized2.substring(0, 8);
  }
}
