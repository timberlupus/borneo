import 'dart:async';

import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:borneo_app/features/routines/models/abstract_routine.dart';
import 'package:borneo_app/features/routines/providers/routine_summary_provider.dart';

class RoutineCardRiverpod extends ConsumerWidget {
  final AbstractRoutine routine;
  const RoutineCardRiverpod(this.routine, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineSummaryState = ref.watch(routineSummaryProvider(routine));
    final routineSummaryNotifier = ref.read(routineSummaryProvider(routine).notifier);

    final colorScheme = Theme.of(context).colorScheme;
    final isActive = routineSummaryState.isActive;
    final bgColor = isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainer;
    final fgColor = isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return _RoutineCardContent(
      isBusy: routineSummaryState.isBusy,
      bgColor: bgColor,
      fgColor: fgColor,
      state: routineSummaryState,
      notifier: routineSummaryNotifier,
      colorScheme: colorScheme,
      isActive: isActive,
    );
  }
}

class _RoutineCardContent extends StatefulWidget {
  final bool isBusy;
  final Color bgColor;
  final Color fgColor;
  final RoutineSummaryState state;
  final RoutineSummaryNotifier notifier;
  final ColorScheme colorScheme;
  final bool isActive;

  const _RoutineCardContent({
    required this.isBusy,
    required this.bgColor,
    required this.fgColor,
    required this.state,
    required this.notifier,
    required this.colorScheme,
    required this.isActive,
  });

  @override
  State<_RoutineCardContent> createState() => _RoutineCardContentState();
}

class _RoutineCardContentState extends State<_RoutineCardContent> {
  bool _showProgress = false;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _RoutineCardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy && !_showProgress) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && widget.isBusy) {
          setState(() => _showProgress = true);
        }
      });
    } else if (!widget.isBusy) {
      _timer?.cancel();
      if (_showProgress) setState(() => _showProgress = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bgColor = widget.bgColor;
    final fgColor = widget.fgColor;
    final colorScheme = widget.colorScheme;
    final isActive = widget.isActive;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Card.filled(
            margin: EdgeInsets.all(0),
            elevation: 0,
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: Column(
                  key: ValueKey(isActive.toString() + state.name),
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final iconSize = constraints.maxHeight - 16.0;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: _buildIcon(state.iconAssetPath, iconSize, fgColor),
                          );
                        },
                      ),
                    ),
                    Text(
                      state.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.0, color: fgColor),
                    ),
                    Divider(height: 16, thickness: 1, color: fgColor.withOpacity(0.2)),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          isActive ? context.translate('ACTIVE') : context.translate('INACTIVE'),
                          style: TextStyle(fontSize: 12, color: fgColor.withOpacity(0.7)),
                        ),
                        Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: widget.isBusy
                              ? null
                              : (v) async {
                                  if (v) {
                                    await widget.notifier.executeRoutine();
                                  } else {
                                    await widget.notifier.undoRoutine();
                                  }
                                },
                          activeColor: colorScheme.primary,
                          inactiveThumbColor: colorScheme.primary,
                          inactiveTrackColor: colorScheme.surfaceBright,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showProgress && widget.isBusy)
            Positioned.fill(
              child: Container(
                color: bgColor.withOpacity(0.6),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon(String iconAssetPath, double iconSize, Color iconColor) {
    if (iconAssetPath.endsWith('.svg')) {
      return SvgPicture.asset(iconAssetPath, height: iconSize, width: iconSize);
    } else {
      return Image.asset(iconAssetPath, height: iconSize, width: iconSize);
    }
  }
}
