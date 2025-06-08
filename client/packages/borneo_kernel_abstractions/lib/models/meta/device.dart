// Device class to represent a WebThings device
import 'package:borneo_kernel_abstractions/models/meta/action.dart';
import 'package:borneo_kernel_abstractions/models/meta/event.dart';
import 'package:borneo_kernel_abstractions/models/meta/property.dart';

class MetaDevice {
  final String id;
  final String title;
  final String? description;
  final List<String> atType;
  final Map<String, MetaProperty> properties = {};
  final Map<String, MetaEvent> events = {};
  final Map<String, MetaAction> actions = {};

  MetaDevice({
    required this.id,
    required this.title,
    this.description,
    this.atType = const [],
  });

  void addProperty(MetaProperty property) => properties[property.name] = property;
  void addEvent(MetaEvent event) => events[event.name] = event;
  void addAction(MetaAction action) => actions[action.name] = action;

  Map<String, dynamic> toJson() => {
        '@context': 'device.borneoiot.com',
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        '@type': atType,
        'properties': {for (var prop in properties.values) prop.name: prop.toJson()},
        'events': {for (var evt in events.values) evt.name: evt.toJson()},
        'actions': {for (var act in actions.values) act.name: act.toJson()},
      };
}
