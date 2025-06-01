import 'dart:convert';
import 'package:borneo_kernel/drivers/borneo/borneo_coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_coap_config.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_probe_coap_config.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:coap/coap.dart';
import 'package:cbor/cbor.dart';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';
import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:event_bus/event_bus.dart';
import 'package:pub_semver/pub_semver.dart';

import '../borneo_device_api.dart';

class LyfiPaths {
  static final Uri info = Uri(path: '/borneo/lyfi/info');
  static final Uri status = Uri(path: '/borneo/lyfi/status');
  static final Uri state = Uri(path: '/borneo/lyfi/state');
  static final Uri color = Uri(path: '/borneo/lyfi/color');
  static final Uri schedule = Uri(path: '/borneo/lyfi/schedule');
  static final Uri mode = Uri(path: '/borneo/lyfi/mode');
  static final Uri correctionMethod =
      Uri(path: '/borneo/lyfi/correction-method');
  static final Uri geoLocation = Uri(path: '/borneo/lyfi/geo-location');
  static final Uri tzEnabled = Uri(path: '/borneo/lyfi/tz/enabled');
  static final Uri tzOffset = Uri(path: '/borneo/lyfi/tz/offset');
  static final Uri acclimation = Uri(path: '/borneo/lyfi/acclimation');
  static final Uri temporaryDuration =
      Uri(path: '/borneo/lyfi/temporary-duration');

  static final Uri sunSchedule = Uri(path: '/borneo/lyfi/sun/schedule');
  static final Uri sunCurve = Uri(path: '/borneo/lyfi/sun/curve');
}

class LyfiCoapDriverData extends BorneoCoapDriverData {
  int debugCounter = 0;
  final LyfiDeviceInfo _lyfiDeviceInfo;

  LyfiCoapDriverData(super._coap, super._probeCoap, super._generalDeviceInfo,
      this._lyfiDeviceInfo);

  LyfiDeviceInfo get lyfiDeviceInfo {
    if (super.isDisposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    return _lyfiDeviceInfo;
  }
}

class BorneoLyfiCoapDriver
    with BorneoDeviceCoapApi
    implements IDriver, ILyfiDeviceApi {
  static const String lyfiCompatibleString = 'bst,borneo-lyfi';

  @override
  Future<bool> probe(Device dev, EventBus deviceEvents,
      {CancellationToken? cancelToken}) async {
    final probeCoapClient = BorneoCoapClient(
      dev.address,
      config: BorneoProbeCoapConfig.coapConfig,
      device: dev,
      offlineDetectionEnabled: false,
    );
    bool succeed = false;
    try {
      // Verify compatible string
      final compatible = await _getCompatible(probeCoapClient);
      if (compatible != lyfiCompatibleString) {
        throw UncompatibleDeviceError(
            "Uncompatible device: `$compatible`", dev);
      }

      // Verify firmware version
      final fwver = await _getFirmwareVersion(probeCoapClient);
      if (!kLyfiFWVersionConstraint.allows(fwver)) {
        throw UnsupportedVersionError(
          'Unsupported firmware version',
          dev,
          currentVersion: fwver,
          versionRange: kLyfiFWVersionConstraint,
        );
      }

      final generalDeviceInfo = await _getGeneralDeviceInfo(probeCoapClient);
      final coapClient = BorneoCoapClient(
        dev.address,
        config: BorneoCoapConfig.coapConfig,
        device: dev,
        deviceEvents: deviceEvents,
        offlineDetectionEnabled: true,
      );
      final lyfiInfo = await _getLyfiInfo(coapClient);
      final driverData = LyfiCoapDriverData(
          coapClient, probeCoapClient, generalDeviceInfo, lyfiInfo);
      await dev.setDriverData(driverData, cancelToken: cancelToken);
      succeed = true;
    } on CoapRequestTimeoutException catch (_) {
      succeed = false;
    } finally {
      if (!succeed) {
        probeCoapClient.close();
      }
    }
    return succeed;
  }

  @override
  Future<bool> remove(Device dev, {CancellationToken? cancelToken}) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    dd.dispose();
    await dev.setDriverData(null, cancelToken: cancelToken);
    return true;
  }

  @override
  Future<bool> heartbeat(Device dev, {CancellationToken? cancelToken}) async {
    try {
      final dd = dev.driverData as LyfiCoapDriverData;
      return await dd.probeCoap.ping().asCancellable(cancelToken);
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {}

  Future<String> _getCompatible(CoapClient coap) async {
    final compatible = await coap.getCbor<String>(
      BorneoPaths.compatible,
    );
    return compatible;
  }

  Future<Version> _getFirmwareVersion(CoapClient coap) async {
    final fwver = await coap.getCbor<String>(
      BorneoPaths.firmwareVersion,
    );
    return Version.parse(fwver);
  }

  Future<GeneralBorneoDeviceInfo> _getGeneralDeviceInfo(CoapClient coap) async {
    final response = await coap.get(
      BorneoPaths.deviceInfo,
      accept: CoapMediaType.applicationCbor,
    );
    return GeneralBorneoDeviceInfo.fromMap(
        cbor.decode(response.payload) as CborMap);
  }

  Future<LyfiDeviceInfo> _getLyfiInfo(CoapClient coap) async {
    final response = await coap.get(
      LyfiPaths.info,
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
    final dd = dev.driverData as LyfiCoapDriverData;
    final response = await dd.coap.get(
      Uri(path: '/borneo/lyfi/thermal/keep-temp'),
      accept: CoapMediaType.applicationCbor,
    );
    return cbor.decode(response.payload).toObject() as int;
  }

  @override
  LyfiDeviceInfo getLyfiInfo(Device dev) {
    final dd = dev.driverData as LyfiCoapDriverData;
    return dd.lyfiDeviceInfo;
  }

  @override
  Future<LyfiDeviceStatus> getLyfiStatus(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
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
    final dd = dev.driverData as LyfiCoapDriverData;
    final result = await dd.coap.getCbor<List<Object?>>(LyfiPaths.color);
    return List<int>.from(result, growable: false);
  }

  @override
  Future<void> setColor(Device dev, List<int> color) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    await dd.coap.putCbor(LyfiPaths.color, color);
  }

  @override
  Future<LedState> getState(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.state);
    return LedState.values[value];
  }

  @override
  Future<void> switchState(Device dev, LedState state) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    await dd.coap.putCbor(LyfiPaths.state, state.index);
  }

  @override
  Future<LedRunningMode> getMode(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.mode);
    return LedRunningMode.values[value];
  }

  @override
  Future<void> switchMode(Device dev, LedRunningMode mode) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    return await dd.coap.putCbor(LyfiPaths.mode, mode.index);
  }

  @override
  Future<List<ScheduledInstant>> getSchedule(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final items = await dd.coap.getCbor<List<dynamic>>(LyfiPaths.schedule);
    return items.map((x) => ScheduledInstant.fromMap(x!)).toList();
  }

  @override
  Future<void> setSchedule(
      Device dev, Iterable<ScheduledInstant> schedule) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final payload = schedule.map((x) => x.toPayload());
    return await dd.coap.putCbor(LyfiPaths.schedule, payload);
  }

  @override
  Future<LedCorrectionMethod> getCorrectionMethod(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.correctionMethod);
    return LedCorrectionMethod.values[value];
  }

  @override
  Future<void> setCorrectionMethod(
      Device dev, LedCorrectionMethod correctionMethod) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    return await dd.coap
        .putCbor(LyfiPaths.correctionMethod, correctionMethod.index);
  }

  @override
  Future<Duration> getTemporaryDuration(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final minutes = await dd.coap.getCbor<int>(LyfiPaths.temporaryDuration);
    return Duration(minutes: minutes);
  }

  @override
  Future<void> setTemporaryDuration(Device dev, Duration duration) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final minutes = duration.inMinutes;
    return await dd.coap.putCbor(LyfiPaths.temporaryDuration, minutes);
  }

  @override
  Future<GeoLocation?> getLocation(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final result = await dd.coap.getCbor<dynamic>(LyfiPaths.geoLocation);
    if (result != null) {
      return GeoLocation.fromMap(result);
    } else {
      return null;
    }
  }

  @override
  Future<void> setLocation(Device dev, GeoLocation location) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    return await dd.coap.putCbor(LyfiPaths.geoLocation, location);
  }

  @override
  Future<bool> getTimeZoneEnabled(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final result = await dd.coap.getCbor<bool>(LyfiPaths.tzEnabled);
    return result;
  }

  @override
  Future<void> setTimeZoneEnabled(Device dev, bool enabled) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    await dd.coap.putCbor(LyfiPaths.tzEnabled, enabled);
  }

  @override
  Future<int> getTimeZoneOffset(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final result = await dd.coap.getCbor<int>(LyfiPaths.tzOffset);
    return result;
  }

  @override
  Future<void> setTimeZoneOffset(Device dev, int offset) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    await dd.coap.putCbor(LyfiPaths.tzOffset, offset);
  }

  @override
  Future<AcclimationSettings> getAcclimation(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final map = await dd.coap.getCbor<dynamic>(LyfiPaths.acclimation);
    return AcclimationSettings.fromMap(map);
  }

  @override
  Future<void> setAcclimation(Device dev, AcclimationSettings acc) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    return await dd.coap.postCbor(LyfiPaths.acclimation, acc);
  }

  @override
  Future<void> terminateAcclimation(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    await dd.coap.delete(LyfiPaths.acclimation);
  }

  @override
  Future<List<ScheduledInstant>> getSunSchedule(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final items = await dd.coap.getCbor<List<dynamic>>(LyfiPaths.sunSchedule);
    return items.map((x) => ScheduledInstant.fromMap(x!)).toList();
  }

  @override
  Future<List<SunCurveItem>> getSunCurve(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final items = await dd.coap.getCbor<List<dynamic>>(LyfiPaths.sunCurve);
    return items.map((x) => SunCurveItem.fromMap(x!)).toList();
  }
}
