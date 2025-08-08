import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

import '../../view_models/lyfi_view_model.dart';
import '../editor/manual_editor_view.dart';
import '../editor/schedule_editor_view.dart';
import '../editor/sun_editor_view.dart';

class DimmingHeroPanel extends StatelessWidget {
  const DimmingHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                      icon: const Icon(Icons.bar_chart_outlined, size: 24),
                    ),
                    ButtonSegment<LyfiMode>(
                      value: LyfiMode.scheduled,
                      label: Text(context.translate('SCHED')),
                      icon: const Icon(Icons.alarm_outlined, size: 24),
                    ),
                    ButtonSegment<LyfiMode>(
                      value: LyfiMode.sun,
                      label: Text(context.translate('SUN')),
                      icon: const Icon(Icons.wb_sunny_outlined, size: 24),
                    ),
                  ],
                  onSelectionChanged: vm.isOn && !vm.isBusy && !vm.isLocked
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
