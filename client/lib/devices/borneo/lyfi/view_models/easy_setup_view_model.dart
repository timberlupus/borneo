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

  Duration get duration => _endTime.value > _startTime.value
      ? _endTime.value - _startTime.value
      : const Duration(hours: 24) - _startTime.value + _endTime.value;

  EasySetupViewModel();

  ScheduleTable build(ScheduleEditorViewModel editor) {
    final blackColor = List<int>.filled(editor.availableChannelCount, 0);
    final start = _startTime.value;
    final end = _endTime.value <= _startTime.value ? _endTime.value + const Duration(hours: 24) : _endTime.value;
    return <ScheduledInstant>[
      ScheduledInstant(instant: start, color: blackColor.toList()),
      ScheduledInstant(instant: start + fadingDuration, color: editor.channels.map((x) => x.value).toList()),
      ScheduledInstant(instant: end - fadingDuration, color: editor.channels.map((x) => x.value).toList()),
      ScheduledInstant(instant: end, color: blackColor.toList()),
    ];
  }
}
