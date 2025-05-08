import 'package:coap/coap.dart';

class BorneoCoapConfig extends DefaultCoapConfig {
  static final DefaultCoapConfig coapConfig = BorneoCoapConfig();

  @override
  String get deduplicator => 'MarkAndSweep';
}
