import 'package:borneo_kernel_abstractions/driver.dart';
import 'package:logger/logger.dart';

/// Produces [Driver] instances on demand.  The kernel core uses a
/// [DriverFactory] instead of constructing drivers directly to decouple the
/// core from concrete implementations and allow plugin/registry schemes.
abstract class DriverFactory {
  /// Instantiate a driver for the given [driverID].  Implementations may
  /// cache and return a singleton or create a new object each call.
  Driver create(String driverID, {Logger? logger});
}
