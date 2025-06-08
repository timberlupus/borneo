// Property class to represent a device property with complex types
import 'dart:async';

class MetaProperty<T> {
  final String name;
  final String title;
  final String type;
  final String? unit;
  final String? description;
  final bool readOnly;
  final Map<String, dynamic>? schema;
  T value;
  final StreamController<T> _valueStream = StreamController.broadcast();

  MetaProperty({
    required this.name,
    required this.title,
    required this.type,
    this.unit,
    this.description,
    this.readOnly = false,
    this.schema,
    required this.value,
  });

  Stream<T> get onValueChanged => _valueStream.stream;

  void setValue(T newValue) {
    if (!readOnly) {
      value = newValue;
      _valueStream.add(newValue);
    }
  }

  Map<String, dynamic> toJson() => {
        '@type': type,
        'title': title,
        'type': type,
        if (unit != null) 'unit': unit,
        if (description != null) 'description': description,
        'readOnly': readOnly,
        if (schema != null) ...schema!,
        'value': value,
      };
}
