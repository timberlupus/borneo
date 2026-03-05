import 'package:borneo_app/devices/borneo/lyfi/view_models/moon_view_model.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/shared/widgets/app_bar_apply_button.dart';
import 'package:borneo_app/shared/widgets/screen_top_rounded_container.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

import 'package:provider/provider.dart';
import 'brightness_slider_list.dart';
import 'widgets/moon_running_chart.dart';

class MoonScreen extends StatelessWidget {
  final String deviceID;
  const MoonScreen({required this.deviceID, super.key});

  Widget buildGraph(BuildContext context, MoonViewModel vm) {
    return Selector<MoonViewModel, ({List<LyfiChannelInfo> channels, ScheduleTable instants})>(
      selector: (context, vm) => (channels: vm.editor.deviceInfo.channels, instants: vm.editor.moonInstants),
      builder: (context, selected, _) =>
          MoonRunningChart(moonInstants: selected.instants, channelInfoList: selected.channels),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = MoonViewModel(
      deviceManager: context.read<IDeviceManager>(),
      globalEventBus: context.read<EventBus>(),
      notification: context.read<IAppNotificationService>(),
      wotThing: context.read<IDeviceManager>().getWotThing(deviceID),
      gt: context.read<GettextLocalizations>(),
      logger: context.read<Logger>(),
    );
    return ChangeNotifierProvider(
      create: (cb) => vm,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(context.translate('Moonlight')),
            actions: [
              Consumer<MoonViewModel>(
                builder: (context, vm, _) =>
                    Switch(value: vm.enabled, onChanged: !vm.isBusy && vm.isOnline && vm.isOn ? vm.setEnabled : null),
              ),
              Consumer<MoonViewModel>(
                builder: (context, vm, _) => AppBarApplyButton(
                  label: context.translate('Apply'),
                  onPressed: vm.canSubmit ? () => onSubmit(vm, context) : null,
                ),
              ),
            ],
          ),
          body: FutureBuilder(
            future: vm.initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: Consumer<MoonViewModel>(builder: (context, vm, _) => buildGraph(context, vm)),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Consumer<MoonViewModel>(
                        builder: (context, vm, _) => ScreenTopRoundedContainer(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          padding: EdgeInsets.fromLTRB(0, 24, 0, 24),
                          child: BrightnessSliderList(vm.editor, disabled: !vm.enabled || !vm.canEdit),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        );
      },
    );
  }

  Future<void> onSubmit(MoonViewModel vm, BuildContext context) async {
    try {
      await vm.submitToDevice();
      if (context.mounted) {
        Provider.of<IAppNotificationService>(
          context,
          listen: false,
        ).showSuccess(context.translate('Update moon settings succeed.'));
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      if (context.mounted) {
        context.read<IAppNotificationService>().showError(context.translate('Error'), body: e.toString());
        vm.logger?.e('Failed to submit moon settings', error: e, stackTrace: st);
      }
    }
  }
}
