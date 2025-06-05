import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:pub_semver/pub_semver.dart';

import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';

import 'lyfi_coap_driver.dart';

const kLyfiDriverID = "borneo.lyfi";
const kLyfiDriverName = "Borneo LyFi Aquarium LED";
final kLyfiFWVersionConstraint = VersionConstraint.parse('>=0.3.0');

final DriverDescriptor borneoLyfiDriverDescriptor = DriverDescriptor(
  id: kLyfiDriverID,
  name: kLyfiDriverName,
  heartbeatMethod: HeartbeatMethod.poll,
  discoveryMethod: MdnsDeviceDiscoveryMethod(kBorneoDeviceMdnsServiceType),
  matches: BorneoLyfiCoapDriver.matches,
  factory: BorneoLyfiCoapDriver.new,
);
