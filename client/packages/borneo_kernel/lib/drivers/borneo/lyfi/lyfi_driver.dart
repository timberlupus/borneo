import 'dart:convert';
import 'package:coap/coap.dart';
import 'package:cbor/cbor.dart';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_common/utils/float.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';
import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';

import '../borneo_device_api.dart';

class LyfiPaths {
  static final Uri info = Uri(path: '/borneo/lyfi/info');
  static final Uri status = Uri(path: '/borneo/lyfi/status');
  static final Uri state = Uri(path: '/borneo/lyfi/state');
  static final Uri color = Uri(path: '/borneo/lyfi/color');
  static final Uri schedule = Uri(path: '/borneo/lyfi/schedule');
  static final Uri sunSchedule = Uri(path: '/borneo/lyfi/sun-schedule');
  static final Uri mode = Uri(path: '/borneo/lyfi/mode');
  static final Uri correctionMethod =
      Uri(path: '/borneo/lyfi/correction-method');
  static final Uri geoLocation = Uri(path: '/borneo/lyfi/geo-location');
}

class LyfiChannelInfo {
  final String name;
  final String color;
  final double brightnessRatio;
  final double power;

  const LyfiChannelInfo({
    required this.name,
    required this.color,
    required this.brightnessRatio,
    required this.power,
  });

  factory LyfiChannelInfo.fromMap(dynamic map) {
    return LyfiChannelInfo(
      name: map['name'],
      color: map['color'],
      brightnessRatio: map['brightnessPercent'].toDouble() / 100.0,
      power: map['power'].toDouble() / 1000.0,
    );
  }
}

class LyfiDeviceInfo {
  final bool isStandaloneController;
  final int channelCount;
  final List<LyfiChannelInfo> channels;

  const LyfiDeviceInfo({
    required this.isStandaloneController,
    required this.channelCount,
    required this.channels,
  });

  factory LyfiDeviceInfo.fromMap(CborMap cborMap) {
    final dynamic map = cborMap.toObject();
    return LyfiDeviceInfo(
        isStandaloneController: map['isStandaloneController'],
        channelCount: map['channelCount'],
        channels: List<LyfiChannelInfo>.from(
          map['channels'].map((x) => LyfiChannelInfo.fromMap(x)),
        ));
  }
}

enum LedState {
  normal,
  dimming,
  nightlight,
  preview,
  poweringOn,
  poweringOff;

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
    return (lat - other.lat).abs() < tolerance &&
        (lng - other.lng).abs() < tolerance;
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

class LyfiDeviceStatus {
  final LedState state;
  final LedRunningMode mode;
  final bool unscheduled;
  final Duration nightlightRemaining;
  final int fanPower;
  final List<int> currentColor;
  final List<int> manualColor;
  final List<int> sunColor;

  double get brightness =>
      currentColor.fold(0, (p, v) => p + v).toDouble() *
      100.0 /
      (currentColor.length * 100.0);

  const LyfiDeviceStatus({
    required this.state,
    required this.mode,
    required this.unscheduled,
    required this.nightlightRemaining,
    required this.fanPower,
    required this.currentColor,
    required this.manualColor,
    required this.sunColor,
  });

  factory LyfiDeviceStatus.fromMap(CborMap cborMap) {
    final dynamic map = cborMap.toObject();
    return LyfiDeviceStatus(
      state: LedState.values[map['state']],
      mode: LedRunningMode.values[map['mode']],
      unscheduled: map['unscheduled'],
      nightlightRemaining: Duration(seconds: map['nlRemain']),
      fanPower: map['fanPower'],
      currentColor: List<int>.from(map['currentColor']),
      manualColor: List<int>.from(map['manualColor']),
      sunColor: List<int>.from(map['sunColor']),
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

abstract class ILyfiDeviceApi extends IBorneoDeviceApi {
  LyfiDeviceInfo getLyfiInfo(Device dev);
  Future<LyfiDeviceStatus> getLyfiStatus(Device dev);

  Future<LedState> getState(Device dev);
  Future<void> switchState(Device dev, LedState state);

  Future<LedRunningMode> getMode(Device dev);
  Future<void> switchMode(Device dev, LedRunningMode mode);

  Future<List<ScheduledInstant>> getSchedule(Device dev);
  Future<void> setSchedule(Device dev, Iterable<ScheduledInstant> schedule);

  Future<List<ScheduledInstant>> getSunSchedule(Device dev);

  Future<List<int>> getColor(Device dev);
  Future<void> setColor(Device dev, List<int> color);

  Future<int> getKeepTemp(Device dev);

  Future<LedCorrectionMethod> getCorrectionMethod(Device dev);
  Future<void> setCorrectionMethod(Device dev, LedCorrectionMethod mode);

  Future<GeoLocation?> getLocation(Device dev);
  Future<void> setLocation(Device dev, GeoLocation location);
}

class LyfiDriverData extends BorneoDriverData {
  int debugCounter = 0;
  final LyfiDeviceInfo _lyfiDeviceInfo;

  LyfiDriverData(super._coap, super._generalDeviceInfo, this._lyfiDeviceInfo);

  LyfiDeviceInfo get lyfiDeviceInfo {
    if (super.isDisposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    return _lyfiDeviceInfo;
  }
}

class BorneoLyfiDriver
    with BorneoDeviceApiImpl
    implements IDriver, ILyfiDeviceApi {
  static const String lyfiCompatibleString = 'bst,borneo-lyfi';

  @override
  Future<bool> probe(Device dev) async {
    final probeCoapClient = CoapClient(dev.address);
    try {
      final generalDeviceInfo = await _getGeneralDeviceInfo(probeCoapClient);
      final lyfiInfo = await _getLyfiInfo(probeCoapClient);
      if (!kLyfiFWVersionConstraint.allows(generalDeviceInfo.fwVer)) {
        throw UnsupportedVersionError(
          'Unsupported firmware version',
          dev,
          currentVersion: generalDeviceInfo.fwVer,
          versionRange: kLyfiFWVersionConstraint,
        );
      }
      final coapClient = CoapClient(dev.address);
      dev.driverData = LyfiDriverData(coapClient, generalDeviceInfo, lyfiInfo);
      return true;
    } finally {
      probeCoapClient.close();
    }
  }

  @override
  Future<bool> remove(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    dd.dispose();
    return true;
  }

  @override
  Future<bool> heartbeat(Device dev) async {
    try {
      await getOnOff(dev);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {}

  Future<GeneralBorneoDeviceInfo> _getGeneralDeviceInfo(CoapClient coap) async {
    final response = await coap.get(
      Uri(path: '/borneo/info'),
      accept: CoapMediaType.applicationCbor,
    );
    return GeneralBorneoDeviceInfo.fromMap(
        cbor.decode(response.payload) as CborMap);
  }

  Future<LyfiDeviceInfo> _getLyfiInfo(CoapClient coap) async {
    final response = await coap.get(
      Uri(path: '/borneo/lyfi/info'),
      accept: CoapMediaType.applicationCbor,
    );
    return LyfiDeviceInfo.fromMap(cbor.decode(response.payload) as CborMap);
  }

  static SupportedDeviceDescriptor? matches(DiscoveredDevice discovered) {
    if (discovered is MdnsDiscoveredDevice) {
      final compatible = utf8.decode(discovered.txt?['compatible'] ?? [],
          allowMalformed: true);
      if (compatible == lyfiCompatibleString) {
        final matched = SupportedDeviceDescriptor(
          driverDescriptor: borneoLyfiDriverDescriptor,
          address:
              Uri(scheme: 'coap', host: discovered.host, port: discovered.port),
          name:
              utf8.decode(discovered.txt?['name'] ?? [], allowMalformed: true),
          compatible: compatible,
          model: utf8.decode(discovered.txt?['model_name'] ?? [],
              allowMalformed: true),
          fingerprint:
              utf8.decode(discovered.txt?['serno'] ?? [], allowMalformed: true),
          manuf: utf8.decode(discovered.txt?['manuf_name'] ?? [],
              allowMalformed: true),
        );
        return matched;
      }
    }
    return null;
  }

  @override
  Future<int> getKeepTemp(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final response = await dd.coap.get(
      Uri(path: '/borneo/lyfi/thermal/keep-temp'),
      accept: CoapMediaType.applicationCbor,
    );
    return cbor.decode(response.payload).toObject() as int;
  }

  @override
  LyfiDeviceInfo getLyfiInfo(Device dev) {
    final dd = dev.driverData as LyfiDriverData;
    return dd.lyfiDeviceInfo;
  }

  @override
  Future<LyfiDeviceStatus> getLyfiStatus(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    dd.debugCounter += 1;
    final response = await dd.coap.get(
      Uri(path: '/borneo/lyfi/status'),
      accept: CoapMediaType.applicationCbor,
    );
    if (dd.debugCounter >= 3) {
      //throw DeviceBusyError('surprise!', dev);
    }
    return LyfiDeviceStatus.fromMap(cbor.decode(response.payload) as CborMap);
  }

  @override
  Future<List<int>> getColor(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final result = await dd.coap.getCbor<List<Object?>>(LyfiPaths.color);
    return List<int>.from(result, growable: false);
  }

  @override
  Future<void> setColor(Device dev, List<int> color) async {
    final dd = dev.driverData as LyfiDriverData;
    await dd.coap.putCbor(LyfiPaths.color, color);
  }

  @override
  Future<LedState> getState(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.state);
    return LedState.values[value];
  }

  @override
  Future<void> switchState(Device dev, LedState state) async {
    final dd = dev.driverData as LyfiDriverData;
    await dd.coap.putCbor(LyfiPaths.state, state.index);
  }

  @override
  Future<LedRunningMode> getMode(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.mode);
    return LedRunningMode.values[value];
  }

  @override
  Future<void> switchMode(Device dev, LedRunningMode mode) async {
    final dd = dev.driverData as LyfiDriverData;
    return await dd.coap.putCbor(LyfiPaths.mode, mode.index);
  }

  @override
  Future<List<ScheduledInstant>> getSchedule(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final items = await dd.coap.getCbor<List<dynamic>>(LyfiPaths.schedule);
    return items.map((x) => ScheduledInstant.fromMap(x!)).toList();
  }

  @override
  Future<void> setSchedule(
      Device dev, Iterable<ScheduledInstant> schedule) async {
    final dd = dev.driverData as LyfiDriverData;
    final payload = schedule.map((x) => x.toPayload());
    return await dd.coap.putCbor(LyfiPaths.schedule, payload);
  }

  @override
  Future<List<ScheduledInstant>> getSunSchedule(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final items = await dd.coap.getCbor<List<dynamic>>(LyfiPaths.sunSchedule);
    return items.map((x) => ScheduledInstant.fromMap(x!)).toList();
  }

  @override
  Future<LedCorrectionMethod> getCorrectionMethod(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.correctionMethod);
    return LedCorrectionMethod.values[value];
  }

  @override
  Future<void> setCorrectionMethod(
      Device dev, LedCorrectionMethod correctionMethod) async {
    final dd = dev.driverData as LyfiDriverData;
    return await dd.coap
        .putCbor(LyfiPaths.correctionMethod, correctionMethod.index);
  }

  @override
  Future<GeoLocation?> getLocation(Device dev) async {
    final dd = dev.driverData as LyfiDriverData;
    final result = await dd.coap.getCbor<dynamic>(LyfiPaths.geoLocation);
    if (result != null) {
      return GeoLocation.fromMap(result);
    } else {
      return null;
    }
  }

  @override
  Future<void> setLocation(Device dev, GeoLocation location) async {
    final dd = dev.driverData as LyfiDriverData;
    return await dd.coap.putCbor(LyfiPaths.geoLocation, location);
  }
}
