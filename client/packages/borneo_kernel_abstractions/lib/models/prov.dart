final class ProvRequest {
  final int version;
  final int id;
  final int method;

  const ProvRequest({required this.method, required this.id, this.version = 1});

  Map<String, dynamic> toMap() => {'v': version, 'id': id, 'm': method};
}

final class ProvResponse {
  final int version;
  final int id;
  final dynamic results;
  final int? errorCode;

  ProvResponse({required this.version, required this.id, required this.results, required this.errorCode});

  factory ProvResponse.fromMap(dynamic map) =>
      ProvResponse(version: map['v'] as int, id: map['id'] as int, results: map['r'], errorCode: map['e']);
}
