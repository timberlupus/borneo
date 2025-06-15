// Dart port of src/property.ts

import 'types.dart';
import 'value.dart';

class WotPropertyMetadata {
  final String? type;
  final String? atType;
  final String? unit;
  final String? title;
  final String? description;
  final List<WotLink>? links;
  final List<dynamic>? enumValues;
  final bool? readOnly;
  final num? minimum;
  final num? maximum;
  final num? multipleOf;

  WotPropertyMetadata({
    this.type,
    this.atType,
    this.unit,
    this.title,
    this.description,
    this.links,
    this.enumValues,
    this.readOnly,
    this.minimum,
    this.maximum,
    this.multipleOf,
  });

  factory WotPropertyMetadata.fromMap(Map<String, dynamic> map) {
    return WotPropertyMetadata(
      type: map['type'],
      atType: map['@type'],
      unit: map['unit'],
      title: map['title'],
      description: map['description'],
      links: map['links'] != null
          ? List<WotLink>.from(
              map['links'].map((l) => WotLink(rel: l['rel'], href: l['href'], mediaType: l['mediaType'])),
            )
          : null,
      enumValues: map['enum'],
      readOnly: map['readOnly'],
      minimum: map['minimum'],
      maximum: map['maximum'],
      multipleOf: map['multipleOf'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (type != null) 'type': type,
      if (atType != null) '@type': atType,
      if (unit != null) 'unit': unit,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (links != null) 'links': links!.map((l) => {'rel': l.rel, 'href': l.href, 'mediaType': l.mediaType}).toList(),
      if (enumValues != null) 'enum': enumValues,
      if (readOnly != null) 'readOnly': readOnly,
      if (minimum != null) 'minimum': minimum,
      if (maximum != null) 'maximum': maximum,
      if (multipleOf != null) 'multipleOf': multipleOf,
    };
  }
}

class WotProperty<T> {
  final String name;
  final WotValue<T> value;
  final WotPropertyMetadata metadata;
  String hrefPrefix = '';
  late final String href;
  final dynamic thing;

  // 修改为命名参数
  WotProperty({required this.thing, required this.name, required this.value, required this.metadata}) {
    href = '/properties/$name';
    // 监听 value 更新，通知 thing
    value.onUpdate.listen((_) => thing?.propertyNotify(this));
  }

  void setHrefPrefix(String prefix) {
    hrefPrefix = prefix;
  }

  String getHref() => hrefPrefix + href;
  T getValue() => value.get();
  void setValue(T newValue) {
    validateValue(newValue);
    value.set(newValue);
  }

  String getName() => name;
  dynamic getThing() => thing;
  WotPropertyMetadata getMetadata() => metadata;

  void validateValue(T v) {
    if (metadata.readOnly == true) {
      throw Exception('Read-only property');
    }
    // 可扩展 schema 校验
  }

  Map<String, dynamic> asPropertyDescription() {
    final desc = Map<String, dynamic>.from(metadata.toMap());
    desc['links'] = (desc['links'] ?? [])..add({'rel': 'property', 'href': getHref()});
    return desc;
  }
}
