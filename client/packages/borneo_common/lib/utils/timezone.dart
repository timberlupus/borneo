String getCstTimeZone() {
  DateTime now = DateTime.now();
  String timeZoneName = now.timeZoneName;
  int offsetHours = now.timeZoneOffset.inHours;
  return "$timeZoneName$offsetHours";
}
