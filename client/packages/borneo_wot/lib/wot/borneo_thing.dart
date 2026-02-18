import 'package:lw_wot/property.dart';
import 'package:lw_wot/thing.dart';
import 'package:lw_wot/value.dart';

abstract class BorneoThing extends WotThing {
  bool get isOffline => !super.getProperty<bool>('online')!;

  BorneoThing({required super.id, required super.title, required super.type, required super.description}) {
    // Online property - indicates connection status
    final onlineProperty = WotProperty<bool>(
      thing: this,
      name: 'online',
      value: WotValue<bool>(
        initialValue: false,
        valueForwarder: (_) => throw UnsupportedError('Online status is read-only'),
      ),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Online',
        description: 'Device connection status',
        readOnly: true,
      ),
    );
    addProperty(onlineProperty);
  }
}
