// Dart port of src/action.ts
// High-level Action base class implementation.

import 'utils.dart' as utils;
import 'thing.dart';
import 'types.dart';

class WotAction<InputType> {
  final String id;
  final WotThing thing;
  final String name;
  final InputType input;
  String hrefPrefix = '';
  late final String href;
  String status = 'created';
  final String timeRequested;
  String? timeCompleted;

  WotAction({required this.id, required this.thing, required this.name, required this.input})
    : timeRequested = utils.timestamp() {
    href = '/actions/$name/$id';
    timeCompleted = null;
  }
  Map<String, dynamic> asActionDescription() {
    final description = <String, dynamic>{
      name: <String, dynamic>{'href': hrefPrefix + href, 'timeRequested': timeRequested, 'status': status},
    };

    if (input != null) {
      (description[name] as Map<String, dynamic>)['input'] = input;
    }

    if (timeCompleted != null) {
      (description[name] as Map<String, dynamic>)['timeCompleted'] = timeCompleted;
    }

    return description;
  }

  void setHrefPrefix(String prefix) {
    hrefPrefix = prefix;
  }

  String getId() => id;
  String getName() => name;
  String getHref() => hrefPrefix + href;
  String getStatus() => status;
  WotThing getThing() => thing;
  String getTimeRequested() => timeRequested;
  String? getTimeCompleted() => timeCompleted;
  InputType getInput() => input;

  void start() {
    status = 'pending';
    thing.actionNotify(this);
    performAction().then((_) => finish(), onError: (_) => finish());
  }

  Future<void> performAction() async {}
  Future<void> cancel() async {}

  void finish() {
    status = 'completed';
    timeCompleted = utils.timestamp();
    thing.actionNotify(this);
  }
}

class ActionMetadata {
  final String? title;
  final String? description;
  final List<WotLink>? links;
  final Map<String, dynamic>? input;
  ActionMetadata({this.title, this.description, this.links, this.input});
}

class ActionDescription<InputType> {
  final String href;
  final String timeRequested;
  final String status;
  final InputType? input;
  final String? timeCompleted;
  ActionDescription({
    required this.href,
    required this.timeRequested,
    required this.status,
    this.input,
    this.timeCompleted,
  });
}
