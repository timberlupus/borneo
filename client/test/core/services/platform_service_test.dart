import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borneo_app/core/services/platform_service.dart';

class FakePlatformService implements PlatformService {
  @override
  bool isAndroid;

  @override
  bool isDesktop;

  @override
  bool isIOS;

  @override
  bool isLinux;

  @override
  bool isMacOS;

  @override
  bool isMobile;

  @override
  bool isWeb;

  FakePlatformService({
    this.isWeb = false,
    this.isAndroid = false,
    this.isIOS = false,
    this.isWindows = false,
    this.isMacOS = false,
    this.isLinux = false,
  }) : isDesktop = isWindows || isMacOS || isLinux,
       isMobile = isAndroid || isIOS;

  @override
  bool isWindows = false;
}

void main() {
  group('PlatformServiceImpl (real)', () {
    final service = PlatformServiceImpl();

    test('flags reflect current runtime', () {
      // can't assert specific values since they vary by host; just ensure
      // consistency between helpers and raw checks.
      expect(service.isWeb, kIsWeb);
      if (!kIsWeb) {
        expect(service.isAndroid, Platform.isAndroid);
        expect(service.isIOS, Platform.isIOS);
        expect(service.isWindows, Platform.isWindows);
        expect(service.isMacOS, Platform.isMacOS);
        expect(service.isLinux, Platform.isLinux);
      }

      expect(service.isMobile, service.isAndroid || service.isIOS);
      expect(service.isDesktop, service.isWindows || service.isMacOS || service.isLinux);
    });
  });

  group('FakePlatformService', () {
    test('allows test-friendly overrides', () {
      final fake = FakePlatformService(isWeb: true, isAndroid: false, isIOS: false);
      expect(fake.isWeb, true);
      expect(fake.isDesktop, false);
      expect(fake.isMobile, false);

      final mobileFake = FakePlatformService(isAndroid: true);
      expect(mobileFake.isMobile, true);
      expect(mobileFake.isDesktop, false);
    });
  });
}
