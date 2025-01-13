import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_kernel_abstractions/device.dart';

abstract class IDriver implements IDisposable {
  const IDriver();
  Future<bool> probe(Device dev);
  Future<bool> remove(Device dev);
  Future<bool> heartbeat(Device dev);
}
