import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:borneo_app/features/my/providers/about_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AboutNotifier', () {
    late ProviderContainer container;

    setUp(() {
      // provide predictable values for PackageInfo
      PackageInfo.setMockInitialValues(
        appName: 'MockApp',
        packageName: 'com.example.mock',
        version: '1.2.3',
        buildNumber: '42',
        buildSignature: 'abc',
      );

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial future returns current package info', () async {
      final info = await container.read(aboutProvider.future);
      expect(info.appName, 'MockApp');
      expect(info.version, '1.2.3');
      expect(info.buildNumber, '42');
    });

    // simple smoke test that watching the provider eventually yields
    // the mocked package info.  more elaborate listener behaviour is not
    // needed for this migration example.
    test('watching provider yields data after initialization', () async {
      final value = container.read(aboutProvider);
      expect(value.isLoading, isTrue);

      final info = await container.read(aboutProvider.future);
      expect(info.appName, 'MockApp');
      expect(container.read(aboutProvider).value, info);
    });
  });
}
