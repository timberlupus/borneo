import 'dart:async';

import 'package:borneo_common/borneo_common.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';

abstract class IMdnsDiscovery extends IDisposable {
  Future<void> stop();
  String get serviceType;
}

abstract class IMdnsProvider {
  Future<IMdnsDiscovery> startDiscovery(String serviceType, EventBus eventBus,
      {CancellationToken? cancelToken});
}

final class NullMdnsDiscovery implements IMdnsDiscovery {
  final String _serviceType;

  NullMdnsDiscovery(this._serviceType);

  @override
  void dispose() {}

  @override
  String get serviceType => _serviceType;

  @override
  Future<void> stop() async {}
}

final class NullMdnsProvider implements IMdnsProvider {
  @override
  Future<IMdnsDiscovery> startDiscovery(String serviceType, EventBus eventBus,
      {CancellationToken? cancelToken}) async {
    return NullMdnsDiscovery(serviceType);
  }
}
