// Dart port of src/event.ts

import 'types.dart';
import 'utils.dart';

class WotEventMetadata {
  final String? type;
  final String? atType;
  final String? unit;
  final String? title;
  final String? description;
  final List<WotLink>? links;
  final num? minimum;
  final num? maximum;
  final num? multipleOf;
  final List<dynamic>? enumValues;

  WotEventMetadata({
    this.type,
    this.atType,
    this.unit,
    this.title,
    this.description,
    this.links,
    this.minimum,
    this.maximum,
    this.multipleOf,
    this.enumValues,
  });
}

class WotEvent<Data> {
  final dynamic thing; // Using dynamic to avoid circular import with WotThing
  final String name;
  final Data? data;
  final String time;
  String hrefPrefix = '';

  WotEvent(this.thing, this.name, [this.data]) : time = timestamp();

  void setHrefPrefix(String prefix) {
    hrefPrefix = prefix;
  }

  String getName() => name;
  Data? getData() => data;
  String getTime() => time;
  dynamic getThing() => thing;
  Map<String, dynamic> asEventDescription() {
    final description = <String, dynamic>{
      name: <String, dynamic>{'timestamp': time},
    };

    if (data != null) {
      (description[name] as Map<String, dynamic>)['data'] = data;
    }

    return description;
  }
}
