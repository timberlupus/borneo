import 'package:flutter/material.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';

import '../adaptive_slider.dart';

/// Helpers that make it easier to build bespoke [SettingsTile] variants used
/// in the application.  The `flutter_settings_ui` package ships only a few
/// constructors; this module provides named helpers for common patterns we
/// reuse elsewhere.

/// Return a tile containing an adaptive slider inside its description slot.
///
/// Using a helper keeps call sites concise and avoids manual layout work.
///
/// Example:
///
/// ```dart
/// settingsSliderTile(
///   title: Text('Duration'),
///   value: vm.days,
///   min: 5,
///   max: 100,
///   onChanged: vm.updateDays,
///   trailing: Text('${vm.days.round()} days'),
/// );
/// ```
AbstractSettingsTile settingsSliderTile({
  required Widget title,
  required double value,
  required ValueChanged<double> onChanged,
  double min = 0,
  double max = 1,
  Widget? trailing,
  Color? backgroundColor,
  bool enabled = true,
  Key? key,
}) {
  return CustomSettingsTile(
    child: AdaptiveSlider(value: value, min: min, max: max, onChanged: onChanged),
  );
}
