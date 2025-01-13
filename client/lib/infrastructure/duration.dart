import 'package:flutter/material.dart';

extension DurationExtension on Duration {
  // Duration 转换为 TimeOfDay
  TimeOfDay toTimeOfDay() {
    int totalMinutes = inMinutes;
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }
}
