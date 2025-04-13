import 'package:pub_semver/pub_semver.dart';

import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:cbor/cbor.dart';
import 'package:coap/coap.dart';
import 'package:cbor/simple.dart' as simple_cbor;

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/device.dart';

const String kBorneoDeviceMdnsServiceType = '_borneo._udp';

class BorneoPaths {
  static final Uri power = Uri(path: '/borneo/power');
  static final Uri powerBehavior = Uri(path: '/borneo/power/behavior');
  static final Uri status = Uri(path: '/borneo/status');
  static final Uri timezone = Uri(path: '/borneo/settings/timezone');
  static final Uri factoryReset = Uri(path: '/borneo/factory/reset');
}

enum PowerBehavior {
  lastState,
  autoOn,
  maintainOff,
}

class GeneralBorneoDeviceInfo {
  final String id;
  final String name;
  final String compatible;
  final String serno;
  final bool hasBT;
  final List<int> btMac;
  final bool hasWifi;
  final List<int> wifiMac;
  final int manufID;
  final String manufName;
  final int modelID;
  final String modelName;
  final Version hwVer;
  final Version fwVer;

  const GeneralBorneoDeviceInfo({
    required this.id,
    required this.name,
    required this.compatible,
    required this.serno,
    this.hasBT = false,
    this.btMac = const [],
    this.hasWifi = false,
    this.wifiMac = const [],
    required this.manufID,
    required this.manufName,
    required this.modelID,
    required this.modelName,
    required this.hwVer,
    required this.fwVer,
  });

  factory GeneralBorneoDeviceInfo.fromMap(CborMap cborMap) {
    final dynamic map = cborMap.toObject();
    return GeneralBorneoDeviceInfo(
      id: map['id'],
      compatible: map['compatible'],
      name: map['name'],
      serno: map['serno'],
      hasBT: map['hasBT'],
      hasWifi: map['hasWifi'],
      wifiMac: map['wifiMac'], // Convert bytes to String
      manufID: map['manufID'],
      manufName: map['manufName'],
      modelID: map['modelID'],
      modelName: map['modelName'],
      hwVer: Version.parse(map['hwVer']),
      fwVer: Version.parse(map['fwVer']),
    );
  }
}

class GeneralBorneoDeviceStatus {
  final bool power;
  final DateTime timestamp;
  final Duration bootDuration;
  final String timezone;
  final int wifiStatus;
  final int? wifiRssi;
  final int btStatus;
  final int serverStatus;
  final int error;
  final int shutdownReason;
  final DateTime? shutdownTimestamp;
  final int? temperature;
  final double? powerVoltage;
  final double? powerCurrent;

  const GeneralBorneoDeviceStatus({
    this.power = false,
    required this.timestamp,
    required this.bootDuration,
    this.timezone = '',
    this.wifiStatus = 0,
    this.wifiRssi,
    this.btStatus = 0,
    this.serverStatus = 0,
    this.error = 0,
    this.shutdownReason = 0,
    this.shutdownTimestamp,
    this.temperature,
    this.powerVoltage,
    this.powerCurrent,
  });

  factory GeneralBorneoDeviceStatus.fromMap(CborMap cborMap) {
    final dynamic map = cborMap.toObject();
    return GeneralBorneoDeviceStatus(
      power: map['power'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] * 1000),
      bootDuration: Duration(milliseconds: map['bootDuration']),
      timezone: map['timezone'] ?? '',
      wifiStatus: map['wifiStatus'],
      wifiRssi: map['wifiRssi'],
      serverStatus: map['serverStatus'],
      error: map['error'],
      shutdownReason: map['shutdownReason'],
      shutdownTimestamp: map['shutdownTimestamp'] > 0
          ? DateTime.fromMillisecondsSinceEpoch(map['shutdownTimestamp'] * 1000)
          : null,
      temperature: map['temperature'],
      powerVoltage: map['powerVoltage']?.toDouble() / 1000.0,
      powerCurrent: map['powerCurrent']?.toDouble() / 1000.0,
    );
  }
}

class BorneoDeviceUpgradeInfo {
  final Version runningVersion;
  final Version newVersion;
  final bool canUpgrade;

  const BorneoDeviceUpgradeInfo({
    required this.runningVersion,
    required this.newVersion,
    required this.canUpgrade,
  });
}

abstract class IBorneoDeviceApi implements IDeviceApi, IPowerOnOffCapability {
  GeneralBorneoDeviceInfo getGeneralDeviceInfo(Device dev);
  Future<GeneralBorneoDeviceStatus> getGeneralDeviceStatus(Device dev);

  Future<PowerBehavior> getPowerBehavior(Device dev);
  Future setPowerBehavior(Device dev, PowerBehavior behavior);

  Future<String> getTimeZone(Device dev);
  Future<void> setTimeZone(Device dev, String timezone);
  Future<void> factoryReset(Device dev);

  Future<void> beginCheckNewVersion();
  Future<bool> isCheckingNewVersionAsync();
  Future<BorneoDeviceUpgradeInfo> getNewVersion();
  Future<void> beginUpgrade();
  Future<bool> isUpgrading();
}

abstract class BorneoDriverData {
  bool _disposed = false;
  final CoapClient _coap;
  final GeneralBorneoDeviceInfo _generalDeviceInfo;

  bool get isDisposed => _disposed;

  BorneoDriverData(this._coap, this._generalDeviceInfo);

  CoapClient get coap {
    if (_disposed) {
      ObjectDisposedException('The object has been disposed.');
    }
    return _coap;
  }

  GeneralBorneoDeviceInfo get generalDeviceInfo {
    if (_disposed) {
      ObjectDisposedException('The object has been disposed.');
    }
    return _generalDeviceInfo;
  }

  void dispose() {
    if (!_disposed) {
      coap.close();
      _disposed = true;
    }
  }
}

mixin BorneoDeviceApiImpl implements IBorneoDeviceApi {
  @override
  Future<bool> getOnOff(Device dev) async {
    final dd = dev.driverData as BorneoDriverData;
    return await dd.coap.getCbor<bool>(BorneoPaths.power);
  }

  @override
  Future setOnOff(Device dev, bool on) async {
    final dd = dev.driverData as BorneoDriverData;
    final response = await dd.coap.putBytes(BorneoPaths.power,
        payload: simple_cbor.cbor.encode(on),
        accept: CoapMediaType.applicationCbor);
    if (!response.isSuccess) {
      throw DeviceError("Failed to post to `${response.location}`", dev);
    }
  }

  @override
  Future<PowerBehavior> getPowerBehavior(Device dev) async {
    final dd = dev.driverData as BorneoDriverData;
    final value = await dd.coap.getCbor<int>(BorneoPaths.powerBehavior);
    return PowerBehavior.values[value];
  }

  @override
  Future setPowerBehavior(Device dev, PowerBehavior behavior) async {
    final dd = dev.driverData as BorneoDriverData;
    final response = await dd.coap.putBytes(BorneoPaths.powerBehavior,
        payload: simple_cbor.cbor.encode(behavior.index),
        accept: CoapMediaType.applicationCbor);
    if (!response.isSuccess) {
      throw DeviceError("Failed to put to `${response.location}`", dev);
    }
  }

  @override
  GeneralBorneoDeviceInfo getGeneralDeviceInfo(Device dev) {
    final dd = dev.driverData as BorneoDriverData;
    return dd.generalDeviceInfo;
  }

  @override
  Future<GeneralBorneoDeviceStatus> getGeneralDeviceStatus(Device dev) async {
    final dd = dev.driverData as BorneoDriverData;
    final response = await dd.coap
        .get(BorneoPaths.status, accept: CoapMediaType.applicationCbor);
    return GeneralBorneoDeviceStatus.fromMap(
        cbor.decode(response.payload) as CborMap);
  }

  @override
  Future<void> factoryReset(Device dev) async {
    final dd = dev.driverData as BorneoDriverData;
    final response = await dd.coap.postBytes(BorneoPaths.factoryReset,
        payload: simple_cbor.cbor.encode(null),
        accept: CoapMediaType.applicationCbor);
    if (!response.isSuccess) {
      throw DeviceError("Failed to put `${response.location}`", dev);
    }
  }

  @override
  Future<void> beginCheckNewVersion() {
    // TODO: implement beginCheckNewVersion
    throw UnimplementedError();
  }

  @override
  Future<void> beginUpgrade() {
    // TODO: implement beginUpgrade
    throw UnimplementedError();
  }

  @override
  Future<BorneoDeviceUpgradeInfo> getNewVersion() {
    // TODO: implement getNewVersion
    throw UnimplementedError();
  }

  @override
  Future<bool> isCheckingNewVersionAsync() {
    // TODO: implement isCheckingNewVersionAsync
    throw UnimplementedError();
  }

  @override
  Future<bool> isUpgrading() {
    // TODO: implement isUpgrading
    throw UnimplementedError();
  }

  @override
  Future<String> getTimeZone(Device dev) async {
    final dd = dev.driverData as BorneoDriverData;
    return await dd.coap.getCbor<String>(BorneoPaths.timezone);
  }

  @override
  Future<void> setTimeZone(Device dev, String timezone) async {
    final dd = dev.driverData as BorneoDriverData;
    final response = await dd.coap.putBytes(BorneoPaths.timezone,
        payload: simple_cbor.cbor.encode(timezone),
        accept: CoapMediaType.applicationCbor);
    if (!response.isSuccess) {
      throw DeviceError("Failed to put to `${response.location}`", dev);
    }
  }
}
