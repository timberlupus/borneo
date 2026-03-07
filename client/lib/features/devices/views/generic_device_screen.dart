import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/view_models/base_device_view_model.dart';
import 'package:borneo_app/features/devices/views/device_availability_guard.dart';

class GenericDeviceScreen<TDeviceViewModel extends BaseDeviceViewModel> extends StatelessWidget {
  const GenericDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = ModalRoute.of(context)!.settings.arguments as DeviceEntity;
    final deviceModuleReg = context.read<IDeviceModuleRegistry>();
    final module = deviceModuleReg.metaModules[device.driverID]!;
    return ChangeNotifierProvider(
      create: (context) => module.detailsViewModelBuilder(context, device.id),
      builder: (context, child) {
        final vm = context.read<TDeviceViewModel>();
        return DeviceAvailabilityGuard<TDeviceViewModel>(
          viewModel: vm,
          child: FutureBuilder(
            future: vm.initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                if (!vm.isAvailable) {
                  return const SizedBox.shrink();
                }
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                return module.detailsViewBuilder(context);
              }
            },
          ),
        );
      },
    );
  }
}
