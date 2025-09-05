import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/abstract_routine.dart';
import '../view_models/routine_summary_view_model.dart';
import '../../../core/services/routine_manager.dart';
import '../../../core/services/app_notification_service.dart';
import 'package:logger/logger.dart';

class RoutineCard extends StatelessWidget {
  final AbstractRoutine routine;
  const RoutineCard(this.routine, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RoutineSummaryViewModel>(
      create: (ctx) => RoutineSummaryViewModel(
        routine,
        routineManager: ctx.read<IRoutineManager>(),
        notification: ctx.read<IAppNotificationService>(),
        logger: ctx.read<Logger?>(),
      ),
      child: const _RoutineCardContentWrapper(),
    );
  }
}

class _RoutineCardContentWrapper extends StatelessWidget {
  const _RoutineCardContentWrapper();
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RoutineSummaryViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = vm.isActive;
    final bgColor = isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainer;
    final fgColor = isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    return _RoutineCardContent(
      vm: vm,
      bgColor: bgColor,
      fgColor: fgColor,
      isActive: isActive,
      colorScheme: colorScheme,
    );
  }
}

class _RoutineCardContent extends StatefulWidget {
  final RoutineSummaryViewModel vm;
  final Color bgColor;
  final Color fgColor;
  final bool isActive;
  final ColorScheme colorScheme;
  const _RoutineCardContent({
    required this.vm,
    required this.bgColor,
    required this.fgColor,
    required this.isActive,
    required this.colorScheme,
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
    if (widget.vm.isBusy && !_showProgress) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 800), () {
        if (mounted && widget.vm.isBusy) setState(() => _showProgress = true);
      });
    } else if (!widget.vm.isBusy) {
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
    final vm = widget.vm;
    final isActive = widget.isActive;
    final fgColor = widget.fgColor;
    final bgColor = widget.bgColor;
    final colorScheme = widget.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Card.filled(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Column(
                  key: ValueKey(isActive.toString() + vm.name),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final iconSize = constraints.maxHeight - 16.0;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: _buildIcon(vm.iconAssetPath, iconSize, fgColor),
                          );
                        },
                      ),
                    ),
                    Text(
                      vm.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.0, color: fgColor),
                    ),
                    Divider(height: 16, thickness: 1, color: fgColor.withValues(alpha: 0.2)),
                    Row(
                      children: [
                        Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(fontSize: 12, color: fgColor.withValues(alpha: 0.7)),
                        ),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: vm.isBusy
                              ? null
                              : (v) async {
                                  if (v) {
                                    await vm.executeRoutine();
                                  } else {
                                    await vm.undoRoutine();
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
          if (_showProgress && vm.isBusy)
            Positioned.fill(
              child: Container(
                color: bgColor.withValues(alpha: 0.6),
                child: const Center(child: CircularProgressIndicator()),
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
