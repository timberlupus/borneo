// Event class to represent device events
class WotEvent {
  final String name;
  final String? description;
  final String? type;
  final Map<String, dynamic>? dataSchema;
  final dynamic data;

  WotEvent({
    required this.name,
    this.description,
    this.type,
    this.dataSchema,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (type != null) 'type': type,
        if (dataSchema != null) 'data': dataSchema,
        if (data != null) 'value': data,
      };
}
