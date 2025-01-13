abstract class Device {
  final String id;
  final Uri address;
  final String fingerprint;
  late dynamic driverData;

  Device({required this.id, required this.fingerprint, required this.address});
}
