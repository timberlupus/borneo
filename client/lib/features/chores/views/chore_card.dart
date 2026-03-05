import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/abstract_chore.dart';
import '../providers/chore_summary_provider.dart';

class ChoreCard extends ConsumerStatefulWidget {
  final AbstractChore chore;
  const ChoreCard(this.chore, {super.key});

  @override
  ConsumerState<ChoreCard> createState() => _ChoreCardState();
}

class _ChoreCardState extends ConsumerState<ChoreCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(choreSummaryProvider(widget.chore.id).notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(choreSummaryProvider(widget.chore.id));
    final notifier = ref.read(choreSummaryProvider(widget.chore.id).notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = state.isActive;
    final bgColor = isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainer;
    final fgColor = isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    const kAnimateDuration = Duration(milliseconds: 300);
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: kAnimateDuration,
            curve: Curves.easeInOut,
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final iconSize = (constraints.maxHeight - 16.0).clamp(0.0, double.infinity);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: _buildIcon(widget.chore.iconAssetPath, iconSize, fgColor),
                        );
                      },
                    ),
                  ),
                  Text(
                    widget.chore.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: textTheme.labelLarge?.fontSize, color: fgColor),
                  ),
                  Divider(height: 16, thickness: 1.5, color: fgColor.withValues(alpha: 0.2)),
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: kAnimateDuration,
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isActive ? context.translate('ACTIVE') : context.translate('INACTIVE'),
                            key: ValueKey(isActive),
                            style: TextStyle(
                              fontSize: textTheme.labelSmall?.fontSize,
                              color: fgColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Switch.adaptive(
                        value: isActive,
                        onChanged: state.isBusy ? null : (v) => v ? notifier.executeChore() : notifier.undoChore(),
                        activeThumbColor: colorScheme.primary,
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
          // Execution progress overlay removed per request (no animation)
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
