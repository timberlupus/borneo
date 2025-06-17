// Property class to represent a device property with complex types
import 'dart:async';

import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';

abstract class WotProperty<T> implements IDisposable {
  bool _isDisposed = false;

  final String name;
  final String title;
  final String atType;
  final String type;
  final String? unit;
  final String? description;
  final bool readOnly;
  final Map<String, dynamic>? schema;
  T _lastValue;
  final StreamController<T> _valueStream = StreamController.broadcast();
  final void Function(T)? valueForwarder;
  final bool Function(T a, T b)? equals;

  WotProperty({
    required this.name,
    required this.title,
    required this.atType,
    required this.type,
    this.unit,
    this.description,
    this.readOnly = false,
    this.schema,
    required T value,
    this.valueForwarder,
    this.equals,
  }) : _lastValue = value;

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
    if (valueForwarder != null) {
      valueForwarder!(newValue);
    }
    this.notifyOfExternalUpdate(newValue);
  }

  T get value => _lastValue;

  void notifyOfExternalUpdate(T newValue) {
    final isEqual = equals != null ? equals!(newValue, _lastValue) : newValue == _lastValue;
    if (newValue != null && !isEqual) {
      _lastValue = newValue;
      _valueStream.add(newValue);
    }
  }

  Map<String, dynamic> toJson() {
    if (_isDisposed) {
      throw ObjectDisposedException();
    }
    return {
      '@type': atType,
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

class WotBooleanProperty extends WotProperty<bool> {
  WotBooleanProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'BooleanProperty', type: 'boolean');
}

class WotOptionalBooleanProperty extends WotProperty<bool?> {
  WotOptionalBooleanProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'OptionalBooleanProperty', type: 'boolean?');
}

class WotIntegerProperty extends WotProperty<int> {
  WotIntegerProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'IntegerProperty', type: 'integer');
}

class WotOptionalIntegerProperty extends WotProperty<int?> {
  WotOptionalIntegerProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'OptionalIntegerProperty', type: 'integer?');
}

class WotNumberProperty extends WotProperty<double> {
  WotNumberProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'NumberProperty', type: 'number');
}

class WotOptionalNumberProperty extends WotProperty<double?> {
  WotOptionalNumberProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'OptionalNumberProperty', type: 'number?');
}

class WotStringProperty extends WotProperty<String> {
  WotStringProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'StringProperty', type: 'string');
}

class WotOptionalStringProperty extends WotProperty<String?> {
  WotOptionalStringProperty({
    required super.name,
    required super.title,
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
  }) : super(atType: 'OptionalStringProperty', type: 'string?');
}

class WotEnumProperty extends WotProperty<String> {
  final List<String> enumeration;

  WotEnumProperty({
    required super.name,
    required super.title,
    required super.atType,
    required super.value,
    required this.enumeration,
    super.readOnly,
    super.description,
    super.valueForwarder,
  }) : super(type: 'string', schema: null, unit: null);
}

class WotOnOffProperty extends WotProperty<bool> {
  WotOnOffProperty({
    required super.value,
    super.readOnly,
    super.unit,
    super.description,
    super.schema,
    super.valueForwarder,
  }) : super(name: "on", title: "On/Off", atType: "OnOffProperty", type: "boolean");
}
