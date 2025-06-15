// Dart port of src/value.ts

import 'dart:async';

typedef WotForwarder<T> = void Function(T value);

class WotValue<T> {
  T _lastValue;
  final WotForwarder<T>? _valueForwarder;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  final bool Function(T a, T b)? _equality;

  WotValue(this._lastValue, [this._valueForwarder, this._equality]);

  void set(T value) {
    if (_valueForwarder != null) {
      _valueForwarder(value);
    }
    notifyOfExternalUpdate(value);
  }

  T get() => _lastValue;

  void notifyOfExternalUpdate(T value) {
    bool isChanged;
    if (_equality != null) {
      isChanged = !_equality(value, _lastValue);
    } else {
      isChanged = value != _lastValue;
    }
    if (isChanged) {
      _lastValue = value;
      _controller.add(value);
    }
  }

  Stream<T> get onUpdate => _controller.stream;
}
