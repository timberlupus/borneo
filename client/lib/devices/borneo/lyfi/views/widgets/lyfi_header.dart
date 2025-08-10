import 'package:borneo_app/shared/widgets/device_status_indicator.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';

import '../../view_models/lyfi_view_model.dart';

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
      title: Selector<LyfiViewModel, String>(selector: (_, vm) => vm.name, builder: (contet, name, _) => Text(name)),
      leading: Selector<LyfiViewModel, bool>(
        selector: (context, vm) => vm.isBusy,
        builder: (context, isBusy, child) =>
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: isBusy ? null : onBack),
      ),
      actions: [
        Selector<LyfiViewModel, RssiLevel?>(
          selector: (_, vm) => vm.rssiLevel,
          builder: (content, rssi, _) => Center(
            child: switch (rssi) {
              null => Icon(Icons.link_off, size: 24, color: Theme.of(context).colorScheme.error),
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
      child: Selector<LyfiViewModel, ({bool isBusy, bool isOnline})>(
        selector: (_, vm) => (isBusy: vm.isBusy, isOnline: vm.isOnline),
        builder: (context, vm, _) => SizedBox(
          height: 1,
          width: double.infinity,
          child: vm.isBusy
              ? LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                )
              : Container(color: Colors.transparent),
        ),
      ),
    );
  }
}

/// Online and timezone status banners shown under AppBar
class LyfiStatusBannersSliver extends StatelessWidget {
  const LyfiStatusBannersSliver({super.key});
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: Column(children: const [_OnlineStatusBanner(), _TimezoneSyncBanner()]));
  }
}

class _OnlineStatusBanner extends StatelessWidget {
  const _OnlineStatusBanner();
  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, bool>(
      selector: (_, vm) => vm.isOnline,
      builder: (context, isOnline, _) {
        final vm = context.read<LyfiViewModel>();
        return DeviceStatusIndicator(isOnline: isOnline, onReconnect: isOnline ? null : vm.reconnect);
      },
    );
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
