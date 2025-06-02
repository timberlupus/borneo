import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TemporaryTile extends StatelessWidget {
  const TemporaryTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({LedState? state, bool canSwitch, Duration total, Duration remain})>(
      selector:
          (context, vm) => (
            state: vm.ledState,
            canSwitch: vm.canSwitchTemporaryState,
            total: vm.temporaryDuration,
            remain: vm.temporaryRemaining.value,
          ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isActive = props.state == LedState.temporary;
        final remainSeconds = props.remain.inSeconds;
        String remainText = '';
        if (isActive && props.total.inSeconds > 0) {
          final min = (remainSeconds ~/ 60).toString().padLeft(2, '0');
          final sec = (remainSeconds % 60).toString().padLeft(2, '0');
          remainText = '$min:$sec';
        }
        return AspectRatio(
          aspectRatio: 2.1,
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: props.canSwitch ? () => context.read<LyfiViewModel>().switchTemporaryState() : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Row(
                    key: ValueKey(isActive.toString() + remainText),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        ),
                        child: Icon(
                          Icons.flashlight_on,
                          size: 20,
                          color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temporary',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isActive && remainText.isNotEmpty)
                              Text(
                                remainText,
                                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                              ),
                          ],
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
