import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/devices/grouped_devices_view_model.dart';
import 'package:borneo_app/views/devices/state_icons.dart';
import 'package:borneo_app/widgets/confirmation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import '../../models/devices/device_entity.dart';
import '../../routes/app_routes.dart';
import '../../view_models/devices/device_summary_view_model.dart';
import 'device_group_selection_sheet.dart';

class DeviceTile extends StatelessWidget {
  final bool isLast;
  const DeviceTile(this.isLast, {super.key});

  void openDevicePage(BuildContext context, DeviceEntity device) {
    var vm = context.read<DeviceSummaryViewModel>();

    Future.delayed(Duration(milliseconds: 200)).then((_) async {
      if (context.mounted) {
        await Navigator.of(context).pushNamed(AppRoutes.makeDeviceScreenRoute(device.driverID), arguments: device);
        vm.notifyListeners();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceSummaryViewModel>(
      builder:
          (context, vm, child) => Column(
            children: [
              ListTile(
                dense: false,
                tileColor: Theme.of(context).colorScheme.surfaceContainer,
                onTap: vm.isBusy ? null : () => openDevicePage(context, vm.deviceEntity),
                onLongPress: () => _showDevicePopMenu(context),
                leading: Container(
                  height: 48,
                  width: 48,
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                      side: BorderSide(width: 1.5, color: Theme.of(context).colorScheme.primaryContainer),
                    ),
                  ),
                  child:
                      vm.deviceModuleMetadata?.deviceIconBuilder(context, 40, vm.isOnline) ??
                      Icon(
                        Icons.device_unknown,
                        color:
                            vm.isOnline
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).disabledColor,
                        size: 40,
                      ),
                ),
                title: Text(vm.deviceEntity.name),
                subtitle: _buildSubtitle(context),
                trailing: _buildPrimaryStateIcon(context),
              ),
              if (!isLast) const Divider(height: 1, indent: 72),
            ],
          ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final vm = context.read<DeviceSummaryViewModel>();
    final status = (isOnline: vm.isOnline, isPowerOn: vm.isPowerOn);
    if (!status.isOnline) {
      return Text(
        context.translate('Off-line'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
      );
    }
    if (!status.isPowerOn) {
      return Text(
        context.translate('OFF'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
      );
    }
    if (vm.deviceModuleMetadata != null) {
      final bound = context.read<DeviceManager>().getBoundDevice(vm.id);
      final widgets = vm.deviceModuleMetadata!.secondaryStatesBuilder(context, bound, vm.deviceEvents);
      if (widgets.isEmpty) return const SizedBox.shrink();
      List<Widget> separated = [];
      for (int i = 0; i < widgets.length; i++) {
        separated.add(widgets[i]);
        if (i != widgets.length - 1) {
          separated.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.fiber_manual_record, size: 4, color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }
      }
      return Row(mainAxisSize: MainAxisSize.min, children: separated);
    } else {
      return Text(
        vm.deviceEntity.model,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
      );
    }
  }

  Widget _buildPrimaryStateIcon(BuildContext context) {
    return Selector<DeviceSummaryViewModel, ({bool isOnline, bool isPowerOn})>(
      selector: (_, vm) => (isOnline: vm.isOnline, isPowerOn: vm.isPowerOn),
      builder: (context, status, child) {
        if (!status.isOnline) {
          return FlashingIcon(icon: Icon(Icons.link_off, size: 24, color: Theme.of(context).colorScheme.error));
        }
        if (!status.isPowerOn) {
          return Icon(Icons.power_settings_new, size: 24, color: Theme.of(context).colorScheme.error);
        }
        final vm = context.read<DeviceSummaryViewModel>();
        if (vm.deviceModuleMetadata?.primaryStateIconBuilder != null) {
          return vm.deviceModuleMetadata!.primaryStateIconBuilder(context, 24);
        }
        return Icon(Icons.error, size: 24, color: Theme.of(context).colorScheme.error);
      },
    );
  }

  void _showDevicePopMenu(BuildContext context) {
    //final vm = context.read<DeviceSummaryViewModel>();
    Rect? rect;
    RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final renderObject = context.findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      rect = renderObject!.paintBounds.shift(offset);
    }
    if (rect != null) {
      showMenu(
        context: context,
        position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
        items: <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'reconnect', child: Text('Reconnect')),
          PopupMenuDivider(),
          PopupMenuItem<String>(value: 'change-group', child: Text('Change group...')),
          PopupMenuItem<String>(value: 'delete', child: Text('Delete...')),
        ],
      ).then((value) {
        if (value != null) {
          // Handle the selected menu item
          if (context.mounted) {
            final parentVM = context.read<GroupedDevicesViewModel>();
            final selectedDeviceVM = context.read<DeviceSummaryViewModel>();
            switch (value) {
              case 'delete':
                {
                  if (context.mounted) {
                    ConfirmationSheet.show(
                      context,
                      message: 'Are you sure to delete the device "${selectedDeviceVM.name}" ?',
                      okPressed: () {
                        parentVM.deleteDevice(selectedDeviceVM.id);
                      },
                    );
                  }
                  break;
                }
              case 'change-group':
                {
                  final groupEntites = parentVM.groups.where((gvm) => !gvm.isDummy).map((gvm) => gvm.model).toList();
                  showModalBottomSheet(
                    context: context,
                    builder:
                        (BuildContext context) => DeviceGroupSelectionSheet(
                          availableGroups: groupEntites,
                          onTapGroup: (g) => parentVM.changeDeviceGroup(selectedDeviceVM.deviceEntity, g?.id),
                          title: 'Change Device Group',
                          subtitle: 'Select the group to which device "${selectedDeviceVM.name}" belongs:',
                        ),
                  );

                  break;
                }
              default:
                break;
            }
          }
        }
      });
    }
  }
}
