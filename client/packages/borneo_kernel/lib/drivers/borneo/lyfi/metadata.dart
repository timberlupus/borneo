import 'package:pub_semver/pub_semver.dart';

import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';

import '../borneo_device_api.dart';
import 'lyfi_driver.dart';

const kLyfiDriverID = "borneo.lyfi";
const kLyfiDriverName = "Borneo LyFi Aquarium LED";
final kLyfiFWVersionConstraint = VersionConstraint.parse('>=0.2.0');

final DriverDescriptor borneoLyfiDriverDescriptor = DriverDescriptor(
  id: kLyfiDriverID,
  name: kLyfiDriverName,
  heartbeatMethod: HeartbeatMethod.poll,
  discoveryMethod: MdnsDeviceDiscoveryMethod(kBorneoDeviceMdnsServiceType),
  matches: BorneoLyfiDriver.matches,
  factory: BorneoLyfiDriver.new,
);
