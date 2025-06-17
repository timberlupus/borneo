// Dart port of src/utils.ts

import 'dart:io';

String timestamp() {
  final date = DateTime.now().toUtc().toIso8601String();
  return date.replaceAll(RegExp(r'\.\d{6}Z$'), '+00:00');
}

/// Get all IP addresses.
///
/// Returns array of addresses.
Future<List<String>> getAddresses() async {
  final addresses = <String>{};

  try {
    final interfaces = await NetworkInterface.list(includeLoopback: false, includeLinkLocal: false);
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        final address = addr.address.toLowerCase();

        // Filter out link-local addresses
        if (addr.type == InternetAddressType.IPv6 && !address.startsWith('fe80:')) {
          addresses.add('[$address]');
        } else if (addr.type == InternetAddressType.IPv4 && !address.startsWith('169.254.')) {
          addresses.add(address);
        }
      }
    }
  } catch (e) {
    // Return empty list if network interfaces can't be accessed
    return [];
  }

  final result = addresses.toList();
  result.sort();
  return result;
}
