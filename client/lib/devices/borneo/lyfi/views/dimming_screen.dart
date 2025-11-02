import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';

import '../view_models/lyfi_view_model.dart';
import 'widgets/lyfi_header.dart';
import 'editor/manual_editor_view.dart';
import 'editor/schedule_editor_view.dart';
import 'editor/sun_editor_view.dart';
// screen_top_rounded_container is used inside slider lists

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
        if (vm.isOnline && !vm.isLocked && !vm.isSuspectedOffline) {
          vm.toggleLock(true);
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                LyfiAppBar(
                  onBack: () {
                    final vm = context.read<LyfiViewModel>();
                    if (!vm.isLocked && !vm.isSuspectedOffline) {
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
            const _ConnectionGuardOverlay(),
          ],
        ),
      ),
    );
  }
}

class DimmingHeroPanel extends StatelessWidget {
  const DimmingHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Selector<LyfiViewModel, LyfiMode>(
            selector: (context, vm) => vm.mode,
            builder: (context, mode, _) {
              final vm = context.read<LyfiViewModel>();
              return SegmentedButton<LyfiMode>(
                showSelectedIcon: false,
                selected: <LyfiMode>{mode},
                segments: [
                  ButtonSegment<LyfiMode>(
                    value: LyfiMode.manual,
                    label: Text(context.translate('MANU')),
                    icon: const Icon(Icons.bar_chart_outlined, size: 16),
                  ),
                  ButtonSegment<LyfiMode>(
                    value: LyfiMode.scheduled,
                    label: Text(context.translate('SCHED')),
                    icon: const Icon(Icons.alarm_outlined, size: 16),
                  ),
                  ButtonSegment<LyfiMode>(
                    value: LyfiMode.sun,
                    label: Text(context.translate('SUN')),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                  ),
                ],
                onSelectionChanged: vm.isOn && !vm.isBusy && !vm.isLocked && !vm.isSuspectedOffline
                    ? (Set<LyfiMode> newSelection) {
                        if (mode != newSelection.single) {
                          vm.switchMode(newSelection.single);
                        }
                      }
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class DimmingView extends StatelessWidget {
  const DimmingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 16,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const DimmingHeroPanel(),
        Expanded(
          child: Selector<LyfiViewModel, ({bool isLocked, LyfiMode mode})>(
            selector: (context, vm) => (isLocked: vm.isLocked, mode: vm.mode),
            builder: (context, vm, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: switch (vm.mode) {
                  LyfiMode.manual => const ManualEditorView(),
                  LyfiMode.scheduled => const ScheduleEditorView(),
                  LyfiMode.sun => const SunEditorView(),
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConnectionGuardOverlay extends StatelessWidget {
  const _ConnectionGuardOverlay();

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, _OverlayState>(
      selector: (context, vm) => _OverlayState(
        isOnline: vm.isOnline,
        isSuspectedOffline: vm.isSuspectedOffline,
        isReconnecting: vm.isReconnecting,
        countdownSeconds: vm.reconnectCountdownSeconds,
      ),
      builder: (context, state, child) {
        final showOffline = !state.isOnline;
        final showSuspected = state.isOnline && state.isSuspectedOffline;
        if (!showOffline && !showSuspected) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final message = showOffline
            ? context.translate('Device connection lost. Controls are locked.')
            : context.translate('Connection unstable. Trying to reconnect…');
        final vm = context.read<LyfiViewModel>();
        final showBackToDevice = ModalRoute.of(context)?.settings.arguments == null;
        final rawCountdown = state.countdownSeconds ?? 0;
        final int countdown = rawCountdown < 0 ? 0 : (rawCountdown > 99 ? 99 : rawCountdown);
        final bool isReconnecting = state.isReconnecting;

        return Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSuspected)
                    const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                  if (showOffline)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.tonalIcon(
                        onPressed: isReconnecting ? null : () => vm.reconnect(),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isReconnecting
                              ? const SizedBox(
                                  key: ValueKey('overlay-progress'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, key: ValueKey('overlay-icon')),
                        ),
                        label: Text(
                          isReconnecting
                              ? '${context.translate("Connecting...")} (${countdown}s)'
                              : context.translate('RETRY'),
                        ),
                      ),
                    ),
                  if (showBackToDevice)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) {
                            final args = route.settings.arguments;
                            if (args is DeviceEntity) {
                              return true;
                            }
                            return route.isFirst;
                          });
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: Text(context.translate('Back to device')),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OverlayState {
  final bool isOnline;
  final bool isSuspectedOffline;
  final bool isReconnecting;
  final int? countdownSeconds;

  const _OverlayState({
    required this.isOnline,
    required this.isSuspectedOffline,
    required this.isReconnecting,
    required this.countdownSeconds,
  });
}
