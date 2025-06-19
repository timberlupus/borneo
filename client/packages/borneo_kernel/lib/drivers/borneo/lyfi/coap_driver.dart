import 'dart:convert';
import 'package:borneo_kernel/drivers/borneo/lyfi/base_lyfi_driver.dart';
import 'package:borneo_kernel/drivers/borneo/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/coap_config.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/coap_driver_data.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/probe_coap_config.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:coap/coap.dart';

import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/metadata.dart';
import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:logger/logger.dart';
import 'package:pub_semver/pub_semver.dart';

class LyfiPaths {
  static final Uri info = Uri(path: '/borneo/lyfi/info');
  static final Uri status = Uri(path: '/borneo/lyfi/status');
  static final Uri state = Uri(path: '/borneo/lyfi/state');
  static final Uri color = Uri(path: '/borneo/lyfi/color');
  static final Uri schedule = Uri(path: '/borneo/lyfi/schedule');
  static final Uri mode = Uri(path: '/borneo/lyfi/mode');
  static final Uri correctionMethod = Uri(path: '/borneo/lyfi/correction-method');
  static final Uri geoLocation = Uri(path: '/borneo/lyfi/geo-location');
  static final Uri tzEnabled = Uri(path: '/borneo/lyfi/tz/enabled');
  static final Uri tzOffset = Uri(path: '/borneo/lyfi/tz/offset');
  static final Uri acclimation = Uri(path: '/borneo/lyfi/acclimation');
  static final Uri temporaryDuration = Uri(path: '/borneo/lyfi/temporary-duration');

  static final Uri sunSchedule = Uri(path: '/borneo/lyfi/sun/schedule');
  static final Uri sunCurve = Uri(path: '/borneo/lyfi/sun/curve');

  static final Uri keepTemp = Uri(path: '/borneo/lyfi/thermal/keep-temp');
}

class BorneoLyfiCoapDriver extends BaseLyfiDriver with BorneoDeviceCoapApi implements IDriver, ILyfiDeviceApi {
  static const String lyfiCompatibleString = 'bst,borneo-lyfi';
  final Logger? logger;

  BorneoLyfiCoapDriver({this.logger});

  @override
  Future<bool> probe(Device dev, {CancellationToken? cancelToken}) async {
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
        throw UncompatibleDeviceError("Uncompatible device: `$compatible`", dev);
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
        offlineDetectionEnabled: true,
      );
      final lyfiInfo = await _getLyfiInfo(coapClient);
      final driverData = LyfiCoapDriverData(dev, coapClient, probeCoapClient, generalDeviceInfo, lyfiInfo);
      driverData.load();
      await dev.setDriverData(driverData, cancelToken: cancelToken);
      succeed = true;
    } on CoapRequestTimeoutException catch (e, stackTrace) {
      logger?.w("Failed to probe device($dev): $e", error: e, stackTrace: stackTrace);
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
    final compatible = await coap.getCbor<String>(BorneoPaths.compatible);
    return compatible;
  }

  Future<Version> _getFirmwareVersion(CoapClient coap) async {
    final fwver = await coap.getCbor<String>(BorneoPaths.firmwareVersion);
    return Version.parse(fwver);
  }

  Future<GeneralBorneoDeviceInfo> _getGeneralDeviceInfo(CoapClient coap) async {
    final payload = await coap.getCbor<Map>(BorneoPaths.deviceInfo);
    return GeneralBorneoDeviceInfo.fromMap(payload);
  }

  Future<LyfiDeviceInfo> _getLyfiInfo(CoapClient coap) async {
    final payload = await coap.getCbor<Map>(LyfiPaths.info);
    return LyfiDeviceInfo.fromMap(payload);
  }

  static SupportedDeviceDescriptor? matches(DiscoveredDevice discovered) {
    if (discovered is MdnsDiscoveredDevice) {
      final compatible = utf8.decode(discovered.txt?['compatible'] ?? [], allowMalformed: true);
      if (compatible == lyfiCompatibleString) {
        final matched = SupportedDeviceDescriptor(
          driverDescriptor: borneoLyfiDriverDescriptor,
          address: Uri(scheme: 'coap', host: discovered.host, port: discovered.port),
          name: utf8.decode(discovered.txt?['name'] ?? [], allowMalformed: true),
          compatible: compatible,
          model: utf8.decode(discovered.txt?['model_name'] ?? [], allowMalformed: true),
          fingerprint: utf8.decode(discovered.txt?['serno'] ?? [], allowMalformed: true),
          manuf: utf8.decode(discovered.txt?['manuf_name'] ?? [], allowMalformed: true),
        );
        return matched;
      }
    }
    return null;
  }

  @override
  Future<int> getKeepTemp(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    return await dd.coap.getCbor<int>(LyfiPaths.keepTemp);
  }

  @override
  LyfiDeviceInfo getLyfiInfo(Device dev, {CancellationToken? cancel}) {
    final dd = dev.driverData as LyfiCoapDriverData;
    return dd.lyfiDeviceInfo;
  }

  @override
  Future<LyfiDeviceStatus> getLyfiStatus(Device dev, {CancellationToken? cancelToken}) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final payload = await dd.coap.getCbor<Map>(LyfiPaths.status, cancelToken: cancelToken);
    return LyfiDeviceStatus.fromMap(payload);
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
  Future<LyfiState> getState(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.state);
    return LyfiState.values[value];
  }

  @override
  Future<void> switchState(Device dev, LyfiState state) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    await dd.coap.putCbor(LyfiPaths.state, state.index);
  }

  @override
  Future<LyfiMode> getMode(Device dev) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    final value = await dd.coap.getCbor<int>(LyfiPaths.mode);
    return LyfiMode.values[value];
  }

  @override
  Future<void> switchMode(Device dev, LyfiMode mode) async {
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
  Future<void> setSchedule(Device dev, Iterable<ScheduledInstant> schedule) async {
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
  Future<void> setCorrectionMethod(Device dev, LedCorrectionMethod correctionMethod) async {
    final dd = dev.driverData as LyfiCoapDriverData;
    return await dd.coap.putCbor(LyfiPaths.correctionMethod, correctionMethod.index);
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
    final dd = dev.data<LyfiCoapDriverData>();
    final items = await dd.coap.getCbor<List<dynamic>>(LyfiPaths.sunCurve);
    return items.map((x) => SunCurveItem.fromMap(x!)).toList();
  }
}
