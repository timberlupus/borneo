import 'package:flutter_test/flutter_test.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/channel_settings_view_model.dart';

class _FakeParent {
  final List<String> names;
  final List<String> colors;

  _FakeParent(int count)
    : names = List<String>.generate(count, (i) => 'ch${i + 1}'),
      colors = List<String>.filled(count, '#FFFFFF');

  String getChannelName(int idx) => names[idx];
  String getChannelColor(int idx) => colors[idx];
  void setChannelName(int idx, String value) {
    names[idx] = value;
  }

  void setChannelColor(int idx, String value) {
    colors[idx] = value;
  }
}

void main() {
  group('ChannelSettingsViewModel', () {
    late _FakeParent parent;
    late ChannelSettingsViewModel vm;

    setUp(() {
      parent = _FakeParent(3);
      vm = ChannelSettingsViewModel(
        index: 1,
        readName: parent.getChannelName,
        readColor: parent.getChannelColor,
        writeName: parent.setChannelName,
        writeColor: parent.setChannelColor,
      );
    });

    test('initial values read from parent', () {
      expect(vm.name, equals('ch2'));
      expect(vm.color, equals('#FFFFFF'));
      expect(vm.changed, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.nameValid, isTrue);
    });

    test('modify name invalidates and triggers validation', () {
      vm.setName('');
      expect(vm.name, isEmpty);
      expect(vm.nameValid, isFalse);
      expect(vm.changed, isTrue);
      expect(vm.canSave, isFalse, reason: 'cannot save when name invalid');
    });

    test('modify color marks changed and enables save when name ok', () {
      vm.setColor('#112233');
      expect(vm.color, equals('#112233'));
      expect(vm.changed, isTrue);
      expect(vm.canSave, isTrue);
    });

    test('save writes back to parent and clears changed flag', () {
      vm.setName('new');
      vm.setColor('#abcdef');
      expect(vm.canSave, isTrue);
      vm.save();
      expect(parent.names[1], equals('new'));
      expect(parent.colors[1], equals('#abcdef'));
      expect(vm.changed, isFalse);
      // subsequent save without changes does nothing
      parent.names[1] = 'foo';
      vm.save();
      expect(parent.names[1], equals('foo'));
    });
  });
}
