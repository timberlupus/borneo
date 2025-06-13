// Device class to represent a WebThings device
import 'package:borneo_common/utils/disposable.dart';
import 'package:borneo_kernel_abstractions/models/wot/action.dart';
import 'package:borneo_kernel_abstractions/models/wot/event.dart';
import 'package:borneo_kernel_abstractions/models/wot/property.dart';

class WotDevice implements IDisposable {
  bool _isDisposed = false;
  final String id;
  final String title;
  final String? description;
  final List<String> type;
  final Map<String, WotProperty> properties = {};
  final Map<String, WotEvent> events = {};
  final Map<String, WotAction> actions = {};

  WotDevice({required this.id, required this.title, this.description, this.type = const []});

  void addProperty(WotProperty property) => properties[property.name] = property;
  void addEvent(WotEvent event) => events[event.name] = event;
  void addAction(WotAction action) => actions[action.name] = action;

  bool hasCapability(String capabilityType) {
    return type.contains(capabilityType);
  }

  bool hasAction(String actionName) => actions.containsKey(actionName);

  bool hasProperty(String propertyName) => properties.containsKey(propertyName);

  bool hasEvent(String eventName) => events.containsKey(eventName);

  Map<String, dynamic> toJson() => {
    '@context': 'device.borneoiot.com',
    'id': id,
    'title': title,
    if (description != null) 'description': description,
    '@type': type,
    'properties': {for (var prop in properties.values) prop.name: prop.toJson()},
    'events': {for (var evt in events.values) evt.name: evt.toJson()},
    'actions': {for (var act in actions.values) act.name: act.toJson()},
  };

  @override
  void dispose() {
    if (!_isDisposed) {
      for (final p in properties.values) {
        p.dispose();
      }

      _isDisposed = true;
    }
  }
}
