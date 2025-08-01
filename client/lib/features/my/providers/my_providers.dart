import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

// PackageInfo Provider
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

// My State Provider (简化版，用于占位)
final myProvider = Provider<String>((ref) {
  return 'my_placeholder';
});
