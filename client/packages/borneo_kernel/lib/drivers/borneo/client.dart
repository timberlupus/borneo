import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/coap_config.dart';
import 'package:coap/coap.dart';
import 'package:cbor/simple.dart' as simple_cbor;

class BorneoClient {
  final Uri baseAddress;
  final bool isLocal;
  late final CoapClient _localCoap;

  BorneoClient(this.baseAddress, this.isLocal) {
    if (isLocal) {
      _localCoap = CoapClient(baseAddress, config: BorneoCoapConfig.coapConfig);
    } else {
      throw UnimplementedError('Remote client was not implemented yet.');
    }
  }

  Future<TResult> get<TResult>(String path, {bool confirmable = true}) async {
    if (isLocal) {
      return await _localGetCbor<TResult>(path, confirmable: confirmable);
    } else {
      throw UnimplementedError('Remote client was not implemented yet.');
    }
  }

  Future<void> put<TPayload>(String path, TPayload payload,
      {bool confirmable = true}) async {
    if (isLocal) {
      return await _localPutCbor<TPayload>(path, payload,
          confirmable: confirmable);
    } else {
      throw UnimplementedError('Remote client was not implemented yet.');
    }
  }

  Future<TResult> post<TPayload, TResult>(String path, TPayload payload,
      {bool confirmable = true}) async {
    if (isLocal) {
      return await _localPostCbor<TPayload, TResult>(path, payload,
          confirmable: confirmable);
    } else {
      throw UnimplementedError('Remote client was not implemented yet.');
    }
  }

  Future<T> _localGetCbor<T>(String path, {required bool confirmable}) async {
    final uri = baseAddress.resolve(path);
    final response = await _localCoap.get(uri,
        accept: CoapMediaType.applicationCbor, confirmable: confirmable);
    if (!response.isSuccess) {
      throw CoapException("Failed to request uri `{uri}`", response);
    }
    return simple_cbor.cbor.decode(response.payload) as T;
  }

  Future<void> _localPutCbor<T>(String path, T payload,
      {required bool confirmable}) async {
    final uri = baseAddress.resolve(path);
    final bytes = simple_cbor.cbor.encode(payload);
    final response = await _localCoap.putBytes(uri,
        payload: bytes,
        accept: CoapMediaType.applicationCbor,
        format: CoapMediaType.applicationCbor,
        confirmable: confirmable);
    if (!response.isSuccess) {
      throw CoapException("Failed to put uri `{uri}`", response);
    }
  }

  Future<TResult> _localPostCbor<TPayload, TResult>(
      String path, TPayload payload,
      {required bool confirmable}) async {
    final uri = baseAddress.resolve(path);
    final bytes = simple_cbor.cbor.encode(payload);
    final response = await _localCoap.postBytes(uri,
        payload: bytes,
        accept: CoapMediaType.applicationCbor,
        format: CoapMediaType.applicationCbor,
        confirmable: confirmable);
    if (!response.isSuccess) {
      throw CoapException("Failed to post uri `{uri}`", response);
    }
    if (TResult != Null) {
      return simple_cbor.cbor.decode(response.payload) as TResult;
    } else {
      return Future<TResult>.value(null);
    }
  }
}
