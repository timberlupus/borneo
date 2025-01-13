import 'package:borneo_common/duration_ext.dart';
import 'package:flutter/material.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/schedule_editor_view_model.dart';
import 'package:progressive_time_picker/progressive_time_picker.dart';
import 'package:provider/provider.dart';

import 'brightness_slider_list.dart';

extension _DurationExtension on Duration {
  PickedTime toPickedTime() {
    int totalMinutes = inMinutes;
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return PickedTime(h: hours, m: minutes);
  }
}

class EasySetupScreen extends StatelessWidget {
  final clockTimeFormat = ClockTimeFormat.twentyFourHours;
  final clockIncrementTimeFormat = ClockIncrementTimeFormat.thirtyMin;

  final ScheduleEditorViewModel editor;

  const EasySetupScreen(this.editor, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: editor,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Easy Setup'),
          ),
          body: Container(
            color: Theme.of(context).colorScheme.surface,
            child: child,
          ),
        );
      },
      child: buildBody(context),
    );
  }

  Widget buildBody(BuildContext context) {
    return Column(
        spacing: 24,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buildList(context));
  }

  List<Widget> buildList(BuildContext context) {
    final listenableDuration = Listenable.merge([
      editor.easySetupViewModel.startTime,
      editor.easySetupViewModel.endTime
    ]);
    return [
      Expanded(
          child: TimePicker(
        drawInitHandlerOnTop: true,
        primarySectors: clockTimeFormat.value,
        secondarySectors: clockTimeFormat.value * 2,
        decoration: TimePickerDecoration(
          baseColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          pickerBaseCirclePadding: 0,
          sweepDecoration: TimePickerSweepDecoration(
            pickerStrokeWidth: 48.0,
            pickerColor: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.5),
            showConnector: false,
          ),
          initHandlerDecoration: TimePickerHandlerDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            shape: BoxShape.circle,
            radius: 20.0,
            icon: Icon(
              Icons.wb_sunny_outlined,
              size: 24.0,
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
          endHandlerDecoration: TimePickerHandlerDecoration(
            color: Theme.of(context).colorScheme.inverseSurface,
            shape: BoxShape.circle,
            radius: 20.0,
            icon: Icon(
              Icons.mode_night_outlined,
              size: 24.0,
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
          primarySectorsDecoration: TimePickerSectorDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            width: 1.0,
            size: 4.0,
            radiusPadding: 0.0,
          ),
          secondarySectorsDecoration: TimePickerSectorDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            width: 1.0,
            size: 2.0,
            radiusPadding: 0,
          ),
          clockNumberDecoration: TimePickerClockNumberDecoration(
            defaultTextColor: Theme.of(context).colorScheme.onSurface,
            positionFactor: 0.45,
            showNumberIndicators: true,
            clockTimeFormat: clockTimeFormat,
            clockIncrementTimeFormat: clockIncrementTimeFormat,
            clockIncrementHourFormat: ClockIncrementHourFormat.three,
          ),
        ),
        initTime: editor.easySetupViewModel.startTime.value.toPickedTime(),
        endTime: editor.easySetupViewModel.endTime.value.toPickedTime(),
        onSelectionChange: (start, end, isDisableRange) {
          editor.easySetupViewModel.startTime.value =
              Duration(hours: start.h, minutes: start.m);
          editor.easySetupViewModel.endTime.value =
              Duration(hours: end.h, minutes: end.m);
        },
        onSelectionEnd: (start, end, isDisableRange) async {
          editor.easySetupViewModel.startTime.value =
              Duration(hours: start.h, minutes: start.m);
          editor.easySetupViewModel.endTime.value =
              Duration(hours: end.h, minutes: end.m);
        },
        child: Column(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
                spacing: 1,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedBuilder(
                    animation: listenableDuration,
                    builder: (context, child) => Text(
                        (editor.easySetupViewModel.duration.inMinutes ~/ 60)
                            .toString()
                            .padLeft(2, '0'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  Text("Hrs",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                  SizedBox(width: 4),
                  AnimatedBuilder(
                    animation: listenableDuration,
                    builder: (context, child) => Text(
                        (editor.easySetupViewModel.duration.inMinutes % 60)
                            .toString()
                            .padLeft(2, '0'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  Text("Mins",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                ]),
            Row(
              spacing: 1,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ValueListenableBuilder<Duration>(
                    valueListenable: editor.easySetupViewModel.startTime,
                    builder: (context, value, child) {
                      return Text(
                          editor.easySetupViewModel.startTime.value.toHHMM(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontFeatures: [
                            FontFeature.tabularFigures()
                          ], color: Theme.of(context).colorScheme.secondary));
                    }),
                const SizedBox(width: 2),
                Icon(Icons.arrow_right_alt_outlined,
                    size: 24, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 2),
                ValueListenableBuilder<Duration>(
                    valueListenable: editor.easySetupViewModel.endTime,
                    builder: (context, value, child) {
                      return Text(
                          editor.easySetupViewModel.endTime.value.toHHMM(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontFeatures: [
                            FontFeature.tabularFigures()
                          ], color: Theme.of(context).colorScheme.secondary));
                    }),
              ],
            ),
            /*
                  Text(
                    '${intl.NumberFormat('00').format(intervalBedTime.h)}Hr ${intl.NumberFormat('00').format(intervalBedTime.m)}Min',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: isSleepGoal ? Color(0xFF3CDAF7) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  */
          ],
        ),
      )),
      Expanded(
        child: Selector<ScheduleEditorViewModel, bool>(
          selector: (_, editor) => editor.canEdit,
          builder: (_, canEdit, __) => BrightnessSliderList(
            editor,
            disabled: !canEdit,
          ),
        ),
      ),
    ];
  }
}
