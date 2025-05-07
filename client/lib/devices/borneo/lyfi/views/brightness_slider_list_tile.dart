import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';

class BrightnessSliderListTile extends StatelessWidget {
  final Color color;
  final bool disabled;
  final int min;
  final int max;
  final int value;
  final String channelName;
  final Widget? trailing;
  final void Function(int) onChanged;

  const BrightnessSliderListTile({
    super.key,
    required this.channelName,
    required this.value,
    required this.color,
    this.disabled = false,
    this.min = 0,
    this.max = lyfiBrightnessMax,
    this.trailing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        dense: true,
        tileColor: Theme.of(context).colorScheme.surfaceContainer,
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        title: FlutterSlider(
          selectByTap: true,
          jump: true,
          disabled: disabled,
          handlerWidth: 24,
          handlerHeight: 24,
          handler: FlutterSliderHandler(
            decoration: BoxDecoration(),
            child: Material(
              type: MaterialType.canvas,
              borderRadius: BorderRadius.circular(32),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Center(
                child: Icon(
                  Icons.chevron_right_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 16,
                ),
              ),
            ),
          ),
          step: const FlutterSliderStep(step: 1, isPercentRange: false),
          values: [value.toDouble()],
          handlerAnimation: FlutterSliderHandlerAnimation(
            curve: Curves.elasticOut,
            reverseCurve: Curves.bounceIn,
            duration: Duration(milliseconds: 300),
            scale: 1.5,
          ),
          max: max.toDouble(),
          min: min.toDouble(),
          tooltip: FlutterSliderTooltip(disabled: true),
          trackBar: FlutterSliderTrackBar(
            activeTrackBarHeight: 8,
            inactiveTrackBarHeight: 8,
            activeTrackBar: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 3.0),
              color: color,
              borderRadius: BorderRadius.circular(4.0),
            ),
            inactiveTrackBar: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          onDragging: (index, low, _) => onChanged(low.toInt()),
          onDragCompleted: (index, low, _) => onChanged(low.toInt()),
        ),
        /*
        leading: Text(
          channelName,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).hintColor,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        */
        trailing: trailing,
      ),
    );
  }
}
