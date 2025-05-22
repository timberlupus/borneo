import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_timezone/flutter_timezone.dart';

// Class to handle timezone conversion from IANA to POSIX
class TimezoneConverter {
  // Cache for zones.json data
  Map<String, dynamic>? _zonesData;

  // Initialize by loading zones.json from assets
  Future<void> init() async {
    if (_zonesData == null) {
      final jsonString = await rootBundle.loadString('assets/data/zones.json');
      _zonesData = jsonDecode(jsonString) as Map<String, dynamic>;
    }
  }

  Future<String?> convertToPosixTimezone(String ianaTimezone) async {
    // Ensure zones.json is loaded
    await init();

    // Lookup POSIX string in zones.json
    if (_zonesData != null && _zonesData!.containsKey(ianaTimezone)) {
      return _zonesData![ianaTimezone] as String?;
    } else {
      // Fallback if timezone not found
      return null;
    }
  }

  Future<String?> convertToIanaTimezone(String posixTimezone) async {
    // Ensure zones.json is loaded
    await init();

    // Reverse lookup for POSIX string in zones.json
    if (_zonesData != null) {
      final ianaTimezone =
          _zonesData!.entries.firstWhere((entry) => entry.value == posixTimezone, orElse: () => MapEntry('', '')).key;
      return ianaTimezone.isNotEmpty ? ianaTimezone : null;
    } else {
      // Fallback if timezone not found
      return null;
    }
  }

  // Get POSIX timezone string for the device's local timezone
  Future<String?> getLocalPosixTimezone() async {
    // Get device's local IANA timezone (e.g., "America/New_York")
    final ianaTimezone = await FlutterTimezone.getLocalTimezone();
    return await convertToPosixTimezone(ianaTimezone);
  }
}
