import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/lyfi_view_model.dart';
import '../widgets/lyfi_header.dart';
import 'dimming_view.dart';

class DimmingScreen extends StatelessWidget {
  static const routeName = '/lyfi/dimming';
  const DimmingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final vm = context.read<LyfiViewModel>();
        if (vm.isOnline && !vm.isLocked) {
          vm.toggleLock(true);
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            LyfiAppBar(
              onBack: () {
                final vm = context.read<LyfiViewModel>();
                if (!vm.isLocked) {
                  vm.toggleLock(true);
                }
                Navigator.of(context).pop();
              },
            ),
            const LyfiBusyIndicatorSliver(),
            const LyfiStatusBannersSliver(),
          ],
          body: const SafeArea(top: false, child: DimmingView()),
        ),
      ),
    );
  }
}
