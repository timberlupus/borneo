import 'package:borneo_app/devices/borneo/lyfi/view_models/moon_view_model.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';

import 'package:provider/provider.dart';
import 'brightness_slider_list.dart';

class MoonScreen extends StatelessWidget {
  final String deviceID;
  const MoonScreen({required this.deviceID, super.key});

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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(context.translate('Moonlight')),
            actions: [
              Consumer<MoonViewModel>(
                builder: (context, vm, _) =>
                    Switch(value: vm.enabled, onChanged: !vm.isBusy && vm.isOnline && vm.isOn ? vm.setEnabled : null),
              ),
              Consumer<MoonViewModel>(
                builder: (context, vm, _) => TextButton.icon(
                  onPressed: vm.canSubmit ? () => onSubmit(vm, context) : null,
                  icon: const Icon(Icons.upload),
                  label: Text(context.translate('Submit')),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: FutureBuilder(
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
                      Expanded(
                        child: ListView(
                          physics: ClampingScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                context.translate('Brightness'),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Consumer<MoonViewModel>(
                              builder: (context, vm, _) =>
                                  BrightnessSliderList(vm.editor, disabled: !vm.enabled || !vm.canEdit),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> onSubmit(MoonViewModel vm, BuildContext context) async {
    await vm.submitToDevice();
    if (context.mounted) {
      Provider.of<IAppNotificationService>(
        context,
        listen: false,
      ).showSuccess(context.translate('Update moon settings succeed.'));
      Navigator.of(context).pop();
    }
  }
}
