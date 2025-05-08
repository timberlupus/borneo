import 'package:coap/coap.dart';

class BorneoProbeCoapConfig extends DefaultCoapConfig {
  static final DefaultCoapConfig coapConfig = BorneoProbeCoapConfig();

  @override
  int get defaultPort => 1;

  @override
  int get defaultSecurePort => 2;

  @override
  int get httpPort => 3;

  @override
  int get ackTimeout => 1;

  @override
  double get ackRandomFactor => 5.0;

  @override
  double get ackTimeoutScale => 1.0;

  @override
  int get maxRetransmit => 1;

  @override
  int get maxMessageSize => 8;

  @override
  int get preferredBlockSize => 9;

  @override
  int get blockwiseStatusLifetime => 10;

  @override
  bool get useRandomIDStart => false;

  @override
  int get notificationMaxAge => 11;

  @override
  int get notificationCheckIntervalTime => 12;

  @override
  int get notificationCheckIntervalCount => 13;

  @override
  int get notificationReregistrationBackoff => 14;

  @override
  int get cropRotationPeriod => 15;

  @override
  int get exchangeLifetime => 16;

  @override
  int get markAndSweepInterval => 17;

  @override
  int get channelReceivePacketSize => 18;

  @override
  String get deduplicator => 'MarkAndSweep';

  @override
  bool get dtlsVerify => false;

  @override
  bool get dtlsWithTrustedRoots => false;
}
