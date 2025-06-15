import 'package:coap/coap.dart';

class BorneoProbeCoapConfig extends DefaultCoapConfig {
  static final DefaultCoapConfig coapConfig = BorneoProbeCoapConfig();

  @override
  int get ackTimeout => 500;

  @override
  double get ackTimeoutScale => 2;
}
