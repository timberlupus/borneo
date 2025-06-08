// Property class to represent a device property with complex types
import 'dart:async';

import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';

class WotProperty<T> implements IDisposable {
  bool _isDisposed = false;

  final String name;
  final String title;
  final String type;
  final String? unit;
  final String? description;
  final bool readOnly;
  final Map<String, dynamic>? schema;
  T value;
  final StreamController<T> _valueStream = StreamController.broadcast();

  WotProperty({
    required this.name,
    required this.title,
    required this.type,
    this.unit,
    this.description,
    this.readOnly = false,
    this.schema,
    required this.value,
  });

  Stream<T> get onValueChanged {
    if (_isDisposed) {
      throw ObjectDisposedException();
    }
    return _valueStream.stream;
  }

  void setValue(T newValue) {
    if (_isDisposed) {
      throw ObjectDisposedException();
    }
    if (!readOnly) {
      value = newValue;
      _valueStream.add(newValue);
    }
  }

  Map<String, dynamic> toJson() {
    if (_isDisposed) {
      throw ObjectDisposedException();
    }
    return {
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

  @override
  void dispose() {
    if (!_isDisposed) {
      _valueStream.close();
      _isDisposed = true;
    }
  }
}
