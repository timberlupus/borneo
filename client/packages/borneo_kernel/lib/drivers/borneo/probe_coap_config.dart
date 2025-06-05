import 'package:coap/coap.dart';

class BorneoProbeCoapConfig extends DefaultCoapConfig {
  static final DefaultCoapConfig coapConfig = BorneoProbeCoapConfig();

  @override
  int get ackTimeout => 100;

  @override
  double get ackTimeoutScale => 1.5;
}
