import 'package:flutter/material.dart';

extension TimeOfDayExtension on TimeOfDay {
  static TimeOfDay fromSeconds(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }

  Duration toDuration() {
    return Duration(hours: hour, minutes: minute);
  }

  static TimeOfDay fromDuration(Duration duration) {
    int totalMinutes = duration.inMinutes;
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }
}
