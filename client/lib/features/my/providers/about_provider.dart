// This file used to contain a ChangeNotifier-based view model for the
// "About" screen.  As part of the Riverpod migration we now expose an
// AsyncNotifier provider so that the UI can watch the state directly and
// the old provider/ChangeNotifier graph can be removed once all consumers
// have been migrated.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Simple provider that lazily loads [PackageInfo] from the platform.
///
/// The notifier only performs work once; subsequent watches receive the
/// previously‑loaded value.  Consumers can use `aboutProvider.future` to
/// await initialization or inspect the [AsyncValue] returned by `watch`.
final aboutProvider = AsyncNotifierProvider<AboutNotifier, PackageInfo>(() => AboutNotifier(), name: 'AboutProvider');

class AboutNotifier extends AsyncNotifier<PackageInfo> {
  @override
  Future<PackageInfo> build() async {
    // Forward the original behaviour of initialize(), which simply
    // fetched the package info and completed.
    return PackageInfo.fromPlatform();
  }
}
