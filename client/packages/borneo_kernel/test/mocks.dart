import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:borneo_kernel_abstractions/idriver_registry.dart';
import 'package:borneo_kernel_abstractions/mdns.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';
import 'package:borneo_kernel_abstractions/models/driver_data.dart';
import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

class MockLogger extends Logger {
  final List<String> logs = [];

  MockLogger() : super(printer: PrettyPrinter());

  @override
  void log(Level level, dynamic message, {Object? error, StackTrace? stackTrace, DateTime? time}) {
    logs.add('[$level] $message');
    super.log(level, message, error: error, stackTrace: stackTrace, time: time);
  }
}

class MockDriver implements IDriver {
  final String id;
  bool _isDisposed = false;
  final Map<String, bool> _probeResults = {};
  final Map<String, bool> _heartbeatResults = {};
  final List<String> _probedDevices = [];
  final List<String> _removedDevices = [];
  final List<String> _heartbeatDevices = [];

  MockDriver(this.id);

  void setProbeResult(String deviceId, bool result) {
    _probeResults[deviceId] = result;
  }

  void setHeartbeatResult(String deviceId, bool result) {
    _heartbeatResults[deviceId] = result;
  }

  List<String> get probedDevices => List.unmodifiable(_probedDevices);
  List<String> get removedDevices => List.unmodifiable(_removedDevices);
  List<String> get heartbeatDevices => List.unmodifiable(_heartbeatDevices);

  @override
  Future<bool> probe(Device dev, {CancellationToken? cancelToken}) async {
    if (_isDisposed) throw StateError('Driver is disposed');
    _probedDevices.add(dev.id);
    return _probeResults[dev.id] ?? true;
  }

  @override
  Future<bool> remove(Device dev, {CancellationToken? cancelToken}) async {
    if (_isDisposed) throw StateError('Driver is disposed');
    _removedDevices.add(dev.id);
    return true;
  }

  @override
  Future<bool> heartbeat(Device dev, {CancellationToken? cancelToken}) async {
    if (_isDisposed) throw StateError('Driver is disposed');
    _heartbeatDevices.add(dev.id);
    return _heartbeatResults[dev.id] ?? true;
  }

  @override
  void dispose() {
    _isDisposed = true;
  }

  bool get isDisposed => _isDisposed;
}

class MockDriverRegistry implements IDriverRegistry {
  final Map<String, DriverDescriptor> _drivers = {};

  void addDriver(String id, DriverDescriptor descriptor) {
    _drivers[id] = descriptor;
  }

  @override
  UnmodifiableMapView<String, DriverDescriptor> get metaDrivers => UnmodifiableMapView(_drivers);
}

class TestDevice extends Device {
  DriverData? _driverData;

  TestDevice(String id, String address) : super(id: id, address: Uri.parse(address), fingerprint: 'test-$id');

  @override
  DriverData get driverData => _driverData ?? TestDriverData(this);

  @override
  Future<void> setDriverData(DriverData driverData, {CancellationToken? cancelToken}) async {
    _driverData = driverData;
  }
}

class TestDriverData extends DriverData {
  TestDriverData(super.device);
}

class MockMdnsDiscovery implements IMdnsDiscovery {
  final String _serviceType;
  bool _isDisposed = false;
  bool _isStopped = false;

  MockMdnsDiscovery(this._serviceType);

  @override
  String get serviceType => _serviceType;

  @override
  Future<void> stop({CancellationToken? cancelToken}) async {
    _isStopped = true;
  }

  @override
  void dispose() {
    _isDisposed = true;
  }

  bool get isDisposed => _isDisposed;
  bool get isStopped => _isStopped;
}

class MockMdnsProvider implements IMdnsProvider {
  final Map<String, MockMdnsDiscovery> _discoveries = {};
  final List<String> _startedServices = [];

  List<String> get startedServices => List.unmodifiable(_startedServices);
  Map<String, MockMdnsDiscovery> get discoveries => Map.unmodifiable(_discoveries);

  @override
  Future<IMdnsDiscovery> startDiscovery(String serviceType, EventBus eventBus, {CancellationToken? cancelToken}) async {
    _startedServices.add(serviceType);
    final discovery = MockMdnsDiscovery(serviceType);
    _discoveries[serviceType] = discovery;
    return discovery;
  }
}

class TestMdnsDiscoveredDevice extends MdnsDiscoveredDevice {
  TestMdnsDiscoveredDevice({
    required String host,
    int? port,
    String? name,
    Map<String, Uint8List?>? txt,
    String? serviceType,
  }) : super(host: host, port: port, name: name, txt: txt, serviceType: serviceType);
}

SupportedDeviceDescriptor createTestDeviceDescriptor(String id, String address, DriverDescriptor driverDescriptor) {
  final uri = address.startsWith('http') ? Uri.parse(address) : Uri.parse('http://$address');
  return SupportedDeviceDescriptor(
    driverDescriptor: driverDescriptor,
    name: 'Test Device $id',
    address: uri,
    fingerprint: 'test-$id',
    compatible: 'test',
    model: 'TestModel',
  );
}

DriverDescriptor createTestDriverDescriptor(String id, MockDriver driver) {
  late final DriverDescriptor descriptor;
  descriptor = DriverDescriptor(
    id: id,
    name: 'Test Driver $id',
    factory: () => driver,
    matches: (discovered) => createTestDeviceDescriptor(id, discovered.host, descriptor),
    heartbeatMethod: HeartbeatMethod.poll,
    discoveryMethod: const MdnsDeviceDiscoveryMethod('_test._tcp'),
  );
  return descriptor;
}
