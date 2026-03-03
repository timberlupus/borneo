import 'package:flutter/material.dart';

/// A view model managing the edits for a single LED channel (name/color).
///
/// Instead of tightly coupling to the controller's view model, this class
/// accepts callbacks for reading and writing data.  This keeps the class
/// small and makes testing trivial.
class ChannelSettingsViewModel extends ChangeNotifier {
  final int index;
  final void Function(int, String) _writeName;
  final void Function(int, String) _writeColor;

  String _name;
  String _initialName;
  String _color;
  String _initialColor;

  ChannelSettingsViewModel({
    required this.index,
    required String Function(int) readName,
    required String Function(int) readColor,
    required void Function(int, String) writeName,
    required void Function(int, String) writeColor,
  }) : _writeName = writeName,
       _writeColor = writeColor,
       _name = readName(index),
       _initialName = readName(index),
       _color = readColor(index),
       _initialColor = readColor(index);

  // ---- getters ----
  String get name => _name;
  String get color => _color;

  bool get nameValid => _validateChannelName(_name);

  bool get changed => _name != _initialName || _color != _initialColor;

  bool get canSave => changed && nameValid;

  // ---- setters ----
  void setName(String value) {
    if (_name != value) {
      _name = value;
      notifyListeners();
    }
  }

  void setColor(String value) {
    if (_color != value) {
      _color = value;
      notifyListeners();
    }
  }

  /// Push edits back via callbacks.
  void save() {
    if (!changed) return;
    if (_name != _initialName) {
      _writeName(index, _name);
    }
    if (_color != _initialColor) {
      _writeColor(index, _color);
    }
    _initialName = _name;
    _initialColor = _color;
  }

  bool _validateChannelName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    try {
      final bytes = value.codeUnits;
      return bytes.isNotEmpty && bytes.length <= 15;
    } catch (_) {
      return false;
    }
  }
}
