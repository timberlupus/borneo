import 'package:borneo_common/utils/float.dart';
import 'package:cbor/cbor.dart';

class LyfiChannelInfo {
  final String name;
  final String color;
  final double brightnessRatio;

  const LyfiChannelInfo({
    required this.name,
    required this.color,
    required this.brightnessRatio,
  });

  factory LyfiChannelInfo.fromMap(dynamic map) {
    return LyfiChannelInfo(
      name: map['name'],
      color: map['color'],
      brightnessRatio: map['brightnessPercent'].toDouble() / 100.0,
    );
  }
}

class LyfiDeviceInfo {
  final bool isStandaloneController;
  final double? nominalPower;
  final int channelCount;
  final List<LyfiChannelInfo> channels;

  const LyfiDeviceInfo({
    required this.isStandaloneController,
    required this.nominalPower,
    required this.channelCount,
    required this.channels,
  });

  factory LyfiDeviceInfo.fromMap(Map map) {
    return LyfiDeviceInfo(
        isStandaloneController: map['isStandaloneController'],
        nominalPower: map['nominalPower']?.toDouble(),
        channelCount: map['channelCount'],
        channels: List<LyfiChannelInfo>.from(
          map['channels'].map((x) => LyfiChannelInfo.fromMap(x)),
        ));
  }
}

enum LedState {
  normal,
  dimming,
  temporary,
  preview;

  bool get isLocked => !(this == preview || this == dimming);
}

enum LedRunningMode {
  manual,
  scheduled,
  sun;

  bool get isSchedulerEnabled => this == scheduled;
}

enum LedCorrectionMethod {
  log,
  linear,
  exp,
  gamma,
  cie1931,
}

class GeoLocation {
  final double lat;
  final double lng;
  GeoLocation({required this.lat, required this.lng});

  @override
  String toString() => "(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})";

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! GeoLocation) {
      return false;
    }
    const double tolerance = 0.00001;
    return (lat - other.lat).abs() < tolerance && (lng - other.lng).abs() < tolerance;
  }

  @override
  int get hashCode => Object.hash(lat, lng);

  factory GeoLocation.fromMap(dynamic map) {
    return GeoLocation(
      lat: map['lat'],
      lng: map['lng'],
    );
  }

  CborMap toCbor() {
    final cborLat = CborFloat(convertToFloat32(lat));
    cborLat.floatPrecision();
    final cborLng = CborFloat(convertToFloat32(lng));
    cborLng.floatPrecision();

    return CborMap({
      CborString("lat"): cborLat,
      CborString("lng"): cborLng,
    });
  }
}

class AcclimationSettings {
  final bool enabled;
  final DateTime startTimestamp;
  final int startPercent;
  final int days;

  AcclimationSettings({
    required this.enabled,
    required this.startTimestamp,
    required this.startPercent,
    required this.days,
  });

  factory AcclimationSettings.fromMap(dynamic map) {
    return AcclimationSettings(
      enabled: map["enabled"],
      startTimestamp: DateTime.fromMillisecondsSinceEpoch(map['startTimestamp'] * 1000, isUtc: true),
      days: map["days"],
      startPercent: map["startPercent"],
    );
  }

  CborMap toCbor() {
    return CborMap({
      CborString("enabled"): CborBool(enabled),
      CborString("startTimestamp"): CborValue((startTimestamp.millisecondsSinceEpoch / 1000.0).round()),
      CborString("startPercent"): CborSmallInt(startPercent),
      CborString("days"): CborSmallInt(days),
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcclimationSettings &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          startTimestamp == other.startTimestamp &&
          startPercent == other.startPercent &&
          days == other.days;

  @override
  int get hashCode => enabled.hashCode ^ startTimestamp.hashCode ^ startPercent.hashCode ^ days.hashCode;
}

class LyfiDeviceStatus {
  final LedState state;
  final LedRunningMode mode;
  final bool unscheduled;
  final Duration temporaryRemaining;
  final int fanPower;
  final List<int> currentColor;
  final List<int> manualColor;
  final List<int> sunColor;
  final bool acclimationEnabled;
  final bool acclimationActivated;

  double get brightness => currentColor.fold(0, (p, v) => p + v).toDouble() * 100.0 / (currentColor.length * 100.0);

  const LyfiDeviceStatus({
    required this.state,
    required this.mode,
    required this.unscheduled,
    required this.temporaryRemaining,
    required this.fanPower,
    required this.currentColor,
    required this.manualColor,
    required this.sunColor,
    this.acclimationEnabled = false,
    this.acclimationActivated = false,
  });

  factory LyfiDeviceStatus.fromMap(Map map) {
    return LyfiDeviceStatus(
      state: LedState.values[map['state']],
      mode: LedRunningMode.values[map['mode']],
      unscheduled: map['unscheduled'],
      temporaryRemaining: Duration(seconds: map['tempRemain']),
      fanPower: map['fanPower'],
      currentColor: List<int>.from(map['currentColor']),
      manualColor: List<int>.from(map['manualColor']),
      sunColor: List<int>.from(map['sunColor']),
      acclimationEnabled: map['acclimationEnabled'] ?? false,
      acclimationActivated: map['acclimationActivated'] ?? false,
    );
  }
}

class ScheduledInstant {
  final Duration instant;
  final List<int> color;
  const ScheduledInstant({required this.instant, required this.color});

  factory ScheduledInstant.fromMap(dynamic map) {
    final secs = map['instant'] as int;
    return ScheduledInstant(
      instant: Duration(seconds: secs),
      color: List<int>.from(map['color'], growable: false),
    );
  }

  List<dynamic> toPayload() {
    return [instant.inSeconds, color];
  }

  bool get isZero => !color.any((x) => x != 0);
}

class SunCurveItem {
  final Duration instant;
  final double brightness;
  const SunCurveItem({required this.instant, required this.brightness});

  factory SunCurveItem.fromMap(Map map) {
    final secs = map['time'] as double;
    return SunCurveItem(
      instant: Duration(seconds: (secs * 3600.0).round()),
      brightness: map['brightness'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SunCurveItem) {
      return false;
    }
    const double tolerance = 0.00001;
    return instant == other.instant && (brightness - other.brightness).abs() < tolerance;
  }

  @override
  int get hashCode => Object.hash(instant, brightness);
}
