extension DurationExtension on Duration {
  String toHHMM() {
    int totalMinutes = inMinutes;
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    String formattedHours = hours.toString().padLeft(2, '0');
    String formattedMinutes = minutes.toString().padLeft(2, '0');

    return '$formattedHours:$formattedMinutes';
  }

  String toHH() {
    int totalMinutes = inMinutes;
    int hours = totalMinutes ~/ 60;

    return hours.toString().padLeft(2, '0');
  }
}
