import 'dart:io';

import 'package:coap/coap.dart';
import 'package:cbor/simple.dart' as simple_cbor;

class CoapException extends IOException {
  final String message;
  final CoapResponse response;
  CoapException(this.message, this.response);

  @override
  String toString() => message;
}

extension CoapClientExtensions on CoapClient {
  //
  Future<T> getCbor<T>(Uri uri, {bool confirmable = true}) async {
    final response = await get(uri,
        accept: CoapMediaType.applicationCbor, confirmable: confirmable);
    if (!response.isSuccess) {
      throw CoapException("Failed to request uri `$uri`", response);
    }
    return simple_cbor.cbor.decode(response.payload) as T;
  }

  //
  Future<void> putCbor<T>(Uri uri, T payload, {bool confirmable = true}) async {
    final bytes = simple_cbor.cbor.encode(payload);
    final response = await putBytes(uri,
        payload: bytes,
        accept: CoapMediaType.applicationCbor,
        format: CoapMediaType.applicationCbor,
        confirmable: confirmable);
    if (!response.isSuccess) {
      throw CoapException("Failed to request uri `$uri`", response);
    }
  }

  Future<void> postCbor<T>(Uri uri, T payload,
      {bool confirmable = true}) async {
    final bytes = simple_cbor.cbor.encode(payload);
    final response = await postBytes(uri,
        payload: bytes,
        accept: CoapMediaType.applicationCbor,
        format: CoapMediaType.applicationCbor,
        confirmable: confirmable);
    if (!response.isSuccess) {
      throw CoapException("Failed to request uri `$uri`", response);
    }
  }
}
