import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/brightness_slider_list.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/color_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/lyfi_view.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/schedule_chart.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/views/common/hex_color.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import '../view_models/sun_editor_view_model.dart';

class SunEditorView extends StatelessWidget {
  const SunEditorView({super.key});

  Widget buildSliders(BuildContext context) {
    return Consumer<SunEditorViewModel>(
      builder: (context, vm, _) {
        if (vm.isInitialized) {
          return Selector<SunEditorViewModel, bool>(
            selector: (_, editor) => editor.canChangeColor,
            builder:
                (_, canChangeColor, __) =>
                    BrightnessSliderList(context.read<SunEditorViewModel>(), disabled: !canChangeColor),
          );
        } else {
          return Container();
        }
      },
    );
  }



  Widget buildTitles(BuildContext context, SunEditorViewModel vm, double value) {
    if (vm.isInitialized) {
      final index = value.toInt();
      final ch = vm.deviceInfo.channels[index];
      return Text(ch.name, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor));
    } else {
      return Text("N/A");
    }
  }

  Widget buildGraph(BuildContext context) {
    return Consumer<SunEditorViewModel>(
      builder: (context, vm, _) {
        return MultiValueListenableBuilder<int>(
          valueNotifiers: vm.channels,
          builder:
              (context, values, _) => ScheduleChart(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rightChevron = Icon(Icons.chevron_right_outlined, color: Theme.of(context).hintColor);
    final tileColor = Theme.of(context).colorScheme.surfaceContainer;
    final items = <Widget>[ListTile(title: const Text('DEVICE INFORMATION'))];

    return ChangeNotifierProvider.value(
      value: context.read<LyfiViewModel>().currentEditor! as SunEditorViewModel,
      builder:
          (context, child) => Column(
            spacing: 16,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainer,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: AspectRatio(
                  aspectRatio: 2.75,
                  child: Consumer<LyfiViewModel>(builder: (conterxt, vm, _) => buildGraph(context)),
                ),
              ),
              Expanded(child: buildSliders(context)),
            ],
          ),
    );
  }
}
