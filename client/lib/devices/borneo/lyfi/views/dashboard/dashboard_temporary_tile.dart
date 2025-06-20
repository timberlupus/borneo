import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class DashboardTemporaryTile extends StatelessWidget {
  const DashboardTemporaryTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({LyfiState? state, bool canSwitch, Duration total, Duration remain})>(
      selector: (context, vm) => (
        state: vm.state,
        canSwitch: vm.canSwitchTemporaryState,
        total: vm.temporaryDuration,
        remain: vm.temporaryRemaining.value,
      ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isActive = props.state == LyfiState.temporary;
        final remainSeconds = props.remain.inSeconds;
        String remainText = '';
        if (isActive && props.total.inSeconds > 0) {
          final min = (remainSeconds ~/ 60).toString().padLeft(2, '0');
          final sec = (remainSeconds % 60).toString().padLeft(2, '0');
          remainText = '$min:$sec';
        }
        final isDisabled = !props.canSwitch;
        final Color bgColor = isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer;
        final Color fgColor = isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;
        final double disabledAlpha = 0.38;
        final Color effectiveFgColor = isDisabled ? fgColor.withValues(alpha: disabledAlpha) : fgColor;
        final Color iconColor = isActive ? theme.colorScheme.onPrimary : theme.colorScheme.primary;
        final Color effectiveIconColor = isDisabled ? iconColor.withValues(alpha: disabledAlpha) : iconColor;
        return AspectRatio(
          aspectRatio: 2.0,
          child: Container(
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: props.canSwitch ? () => context.read<LyfiViewModel>().switchTemporaryState() : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                            child: isActive
                                ? SizedBox(
                                    key: const ValueKey('active'),
                                    width: 24,
                                    height: 24,
                                    child: Padding(
                                      padding: EdgeInsets.all(4),
                                      child: CircularProgressIndicator(
                                        strokeAlign: 1,
                                        strokeWidth: 2,
                                        value: props.total.inSeconds > 0
                                            ? props.remain.inSeconds / props.total.inSeconds
                                            : 0.0,
                                        backgroundColor: theme.colorScheme.shadow,
                                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimaryContainer),
                                      ),
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('inactive'),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.flashlight_on, size: 24, color: effectiveIconColor),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Temporary', style: theme.textTheme.titleSmall?.copyWith(color: effectiveFgColor)),
                                if (isActive && remainText.isNotEmpty)
                                  Text(
                                    remainText,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: effectiveFgColor,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isActive)
                        Positioned(
                          right: -16,
                          bottom: -16,
                          child: Icon(
                            Icons.flashlight_on,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
