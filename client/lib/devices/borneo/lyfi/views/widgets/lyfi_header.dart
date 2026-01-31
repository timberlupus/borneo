import 'package:borneo_common/io/net/rssi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';

import '../../view_models/lyfi_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

/// Sliver AppBar for Lyfi device details, to be shared by Dashboard and Dimming screens.
class LyfiAppBar extends StatelessWidget {
  final VoidCallback? onBack;
  const LyfiAppBar({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: false,
      floating: false,
      snap: false,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Selector<LyfiViewModel, ({String name, String model})>(
        selector: (_, vm) => (name: vm.name, model: vm.deviceEntity.model),
        builder: (context, data, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.name, style: Theme.of(context).textTheme.titleMedium),
            Text(data.model, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      leading: Selector<LyfiViewModel, bool>(
        selector: (context, vm) => vm.isBusy,
        builder: (context, isBusy, child) =>
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: isBusy ? null : onBack),
      ),
      actions: [
        Selector<LyfiViewModel, LyfiMode>(
          selector: (_, vm) => vm.mode,
          builder: (context, mode, _) {
            final modeIcon = switch (mode) {
              LyfiMode.manual => Icons.bar_chart_outlined,
              LyfiMode.scheduled => Icons.alarm_outlined,
              LyfiMode.sun => Icons.wb_sunny_outlined,
            };
            return Icon(modeIcon, size: 24);
          },
        ),
        const SizedBox(width: 8),
        Selector<LyfiViewModel, RssiLevel?>(
          selector: (_, vm) => vm.rssiLevel,
          builder: (content, rssi, _) => Center(
            child: switch (rssi) {
              null => Icon(Icons.wifi_off, size: 24, color: Theme.of(context).colorScheme.error),
              RssiLevel.strong => const Icon(Icons.wifi_rounded, size: 24),
              RssiLevel.medium => const Icon(Icons.wifi_2_bar_rounded, size: 24),
              RssiLevel.weak => const Icon(Icons.wifi_1_bar_rounded, size: 24),
            },
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// Top linear busy indicator under the AppBar
class LyfiBusyIndicatorSliver extends StatelessWidget {
  const LyfiBusyIndicatorSliver({super.key});
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Selector<LyfiViewModel, bool>(
        selector: (_, vm) => vm.isBusy,
        builder: (context, isBusy, _) {
          if (!isBusy) {
            return const SizedBox.shrink();
          }
          return const LinearProgressIndicator(minHeight: 2);
        },
      ),
    );
  }
}

class LyfiStatusBannersSliver extends StatelessWidget {
  const LyfiStatusBannersSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: _TimezoneSyncBanner());
  }
}

class _TimezoneSyncBanner extends StatelessWidget {
  const _TimezoneSyncBanner();

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({bool hasTimezoneMismatch, bool isOnline})>(
      selector: (_, vm) => (hasTimezoneMismatch: vm.hasTimezoneMismatch, isOnline: vm.isOnline),
      builder: (context, props, _) {
        if (!props.hasTimezoneMismatch || !props.isOnline) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Device timezone is different from app timezone',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: () {
                  final vm = context.read<LyfiViewModel>();
                  vm.syncDeviceTimezone();
                },
                child: Text(context.translate('Sync Timezone')),
              ),
            ],
          ),
        );
      },
    );
  }
}
