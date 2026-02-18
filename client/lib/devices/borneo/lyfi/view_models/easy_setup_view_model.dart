import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/foundation.dart';

import 'editor/schedule_editor_view_model.dart';

const Duration fadingDuration = Duration(minutes: 30);
const Duration defaultStartTime = Duration(hours: 7);
const Duration defaultEndTime = Duration(hours: 17);

class EasySetupViewModel extends ChangeNotifier {
  final ValueNotifier<Duration> _startTime = ValueNotifier(defaultStartTime);
  ValueNotifier<Duration> get startTime => _startTime;

  final ValueNotifier<Duration> _endTime = ValueNotifier(defaultEndTime);
  ValueNotifier<Duration> get endTime => _endTime;

  // Temporary channel values used only inside Easy Setup UI. These are
  // independent from the editor's channels until the user taps Apply.
  final List<ValueNotifier<int>> _channels = [];
  List<ValueNotifier<int>> get channels => _channels;

  List<int> get channelValues => _channels.map((c) => c.value).toList();

  Duration get duration => _endTime.value > _startTime.value
      ? _endTime.value - _startTime.value
      : const Duration(hours: 24) - _startTime.value + _endTime.value;

  EasySetupViewModel();

  void initChannelsFromList(List<int> values) {
    _channels.clear();
    _channels.addAll(values.map((v) => ValueNotifier<int>(v)));
  }

  ScheduleTable build(ScheduleEditorViewModel? editor) {
    final channelCount = _channels.isNotEmpty ? _channels.length : (editor != null ? editor.availableChannelCount : 0);
    final blackColor = List<int>.filled(channelCount, 0);
    final currentColor = _channels.isNotEmpty
        ? _channels.map((c) => c.value).toList()
        : (editor != null ? editor.channels.map((x) => x.value).toList() : List<int>.filled(channelCount, 0));

    final start = _startTime.value;
    final end = _endTime.value <= _startTime.value ? _endTime.value + const Duration(hours: 24) : _endTime.value;
    return <ScheduledInstant>[
      ScheduledInstant(instant: start, color: blackColor.toList()),
      ScheduledInstant(instant: start + fadingDuration, color: currentColor),
      ScheduledInstant(instant: end - fadingDuration, color: currentColor),
      ScheduledInstant(instant: end, color: blackColor.toList()),
    ];
  }
}
