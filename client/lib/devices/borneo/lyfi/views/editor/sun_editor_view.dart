import 'package:borneo_app/devices/borneo/lyfi/views/brightness_slider_list.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/sun_running_chart.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import 'package:provider/provider.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import '../../view_models/editor/sun_editor_view_model.dart';

class SunEditorView extends StatelessWidget {
  const SunEditorView({super.key});

  Widget buildSliders(BuildContext context) {
    return Consumer<SunEditorViewModel>(
      builder: (context, vm, _) {
        if (vm.isInitialized) {
          return Selector<SunEditorViewModel, bool>(
            selector: (_, editor) => editor.canChangeColor,
            builder:
                (_, canChangeColor, _) =>
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
      return Text(context.translate("N/A"));
    }
  }

  Widget buildGraph(BuildContext context) {
    return Selector<SunEditorViewModel, ({List<LyfiChannelInfo> channels, List<ScheduledInstant> instants})>(
      selector: (context, vm) => (channels: vm.parent.lyfiDeviceInfo.channels, instants: vm.sunInstants),
      builder:
          (context, selected, _) => SunRunningChart(sunInstants: selected.instants, channelInfoList: selected.channels),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEditor = context.read<LyfiViewModel>().currentEditor!;

    return ChangeNotifierProvider.value(
      value: currentEditor as SunEditorViewModel,
      builder:
          (context, child) => Column(
            spacing: 16,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainer,
                padding: const EdgeInsets.all(0),
                child: AspectRatio(
                  aspectRatio: 2.75,
                  child: Consumer<SunEditorViewModel>(builder: (conterxt, vm, _) => buildGraph(context)),
                ),
              ),
              Expanded(child: buildSliders(context)),
            ],
          ),
    );
  }
}
