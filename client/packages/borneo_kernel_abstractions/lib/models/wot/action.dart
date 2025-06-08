// Action class to represent device actions
import 'dart:async';

class WotAction {
  final String name;
  final String? title;
  final String? description;
  final Map<String, dynamic>? inputSchema;
  final Completer<void> _completer = Completer();

  WotAction({
    required this.name,
    this.title,
    this.description,
    this.inputSchema,
  });

  Future<void> get completion => _completer.future;

  void complete() => _completer.complete();

  Map<String, dynamic> toJson() => {
        'name': name,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (inputSchema != null) 'input': inputSchema,
      };
}
