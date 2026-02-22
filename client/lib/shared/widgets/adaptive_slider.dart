import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdaptiveSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const AdaptiveSlider({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 1});

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return CupertinoSlider(value: value, min: min, max: max, onChanged: onChanged);
    }

    return Slider(value: value, min: min, max: max, onChanged: onChanged);
  }
}
