import 'package:borneo_app/routes/app_routes.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/i_app_notification_service.dart';
import 'package:borneo_app/core/services/routine_manager.dart';
import 'package:borneo_app/features/devices/view_models/group_edit_view_model.dart';
import 'package:borneo_app/features/scenes/view_models/scene_edit_view_model.dart';
import 'package:borneo_app/features/devices/views/group_edit_screen.dart';
import 'package:borneo_app/features/scenes/views/scene_edit_screen.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../../core/services/device_manager.dart';
import '../../core/services/scene_manager.dart';
import '../../features/devices/view_models/grouped_devices_view_model.dart';
import '../../features/scenes/view_models/scenes_view_model.dart';
import '../../features/my/view_models/my_view_model.dart';
import '../../features/scenes/views/scenes_screen.dart';
import '../../features/devices/views/devices_screen.dart';
import '../../features/my/views/my_screen.dart';

import '../view_models/main_view_model.dart';

enum PlusMenuIndexes { addScene, addGroup, addDevice }

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar({super.key});
  String _getTitle(BuildContext context, MainViewModel vm) {
    switch (vm.currentTabIndex) {
      case TabIndices.devices:
        return vm.currentSceneName;
      case TabIndices.scenes:
        return context.translate("Scenes");
      case TabIndices.my:
        return context.translate("My");
    }
  }

  Future<void> showDiscoveryScreen(BuildContext context) async {
    await Navigator.of(context).pushNamed(AppRoutes.kDeviceDiscovery);
  }

  Future<void> showNewGroupScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupEditScreen(),
        settings: RouteSettings(arguments: GroupEditArguments(isCreation: true)),
      ),
    );
  }

  Future<void> showNewSceneScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SceneEditScreen(args: SceneEditArguments(isCreation: true))),
    );
  }

  PopupMenuButton buildAddButtons(BuildContext context) {
    return PopupMenuButton<PlusMenuIndexes>(
      icon: Icon(Icons.add_outlined),
      onSelected: (value) {
        switch (value) {
          case PlusMenuIndexes.addGroup:
            {
              showNewGroupScreen(context);
              break;
            }
          case PlusMenuIndexes.addScene:
            {
              showNewSceneScreen(context);
              break;
            }
          case PlusMenuIndexes.addDevice:
            {
              showDiscoveryScreen(context);
              break;
            }
        }
        // Handle menu item selection
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<PlusMenuIndexes>>[
          PopupMenuItem<PlusMenuIndexes>(
            value: PlusMenuIndexes.addDevice,
            child: Text(context.translate('Add New Devices')),
          ),
          PopupMenuDivider(),
          PopupMenuItem<PlusMenuIndexes>(value: PlusMenuIndexes.addScene, child: Text(context.translate('Add Scene'))),
          PopupMenuItem<PlusMenuIndexes>(
            value: PlusMenuIndexes.addGroup,
            child: Text(context.translate('Add Devices Group')),
          ),
        ];
      },
    );
  }

  @override
  Widget build(Object context) {
    final bc = context as BuildContext;
    final vm = bc.read<MainViewModel>();
    return AppBar(
      /*
        flexibleSpace: FlexibleSpaceBar(
          background: Image.asset(
            'assets/images/scene-bg-default.jpg',
            fit: BoxFit.cover,
          ),
        ),
        */
      title: Column(children: [Text(_getTitle(context, vm))]),
      actions: [
        Selector<MainViewModel, ({bool isInit, bool isScanningDevices, TabIndices index})>(
          selector: (_, vm) =>
              (isInit: vm.isInitialized, isScanningDevices: vm.isScanningDevices, index: vm.currentTabIndex),
          builder: (_, vm, _) => !vm.isInit || vm.isScanningDevices
              ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
              : buildAddButtons(context),
        ),
      ],
    );
  }

  @override
  // TODO: implement preferredSize
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Widget buildScaffold(BuildContext context) {
    final mainVM = context.read<MainViewModel>();
    return Selector<MainViewModel, TabIndices>(
      selector: (context, vm) => vm.currentTabIndex,
      builder: (context, tabIndex, child) => Scaffold(
        appBar: null,

        // page body
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: switch (tabIndex) {
            TabIndices.devices => const DevicesScreen(key: ValueKey('devices')),
            TabIndices.scenes => const ScenesScreen(key: ValueKey('scenes')),
            TabIndices.my => const MyScreen(key: ValueKey('my')),
          },
        ),

        // bottom
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: tabIndex.index,
          onTap: (index) {
            if (index != tabIndex.index) {
              mainVM.setIndex(TabIndices.values[index]);
            }
          },
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.house_outlined), label: context.translate('Scenes')),
            BottomNavigationBarItem(icon: Icon(Icons.device_hub), label: context.translate('Devices')),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: context.translate('My')),
          ],
        ),
      ),
    );
  }

  void showRescanDevicesDialog(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Text('Loading...')]),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(context);
                },
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final bus = context.read<EventBus>();
        final bm = context.read<IBlobManager>();
        final sm = context.read<SceneManager>();
        final gm = context.read<GroupManager>();
        final dm = context.read<DeviceManager>();
        return MainViewModel(bus, bm, sm, gm, dm, logger: context.read<Logger>());
      },
      lazy: false,
      child: Builder(
        builder: (context) {
          final vm = context.read<MainViewModel>();

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;

              final shouldPop = await vm.handleWillPop();
              if (!shouldPop) {
                Provider.of<IAppNotificationService>(context, listen: false).showInfo('Press back again to exit');
              } else if (context.mounted) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  SystemNavigator.pop();
                }
              }
            },
            child: Selector<MainViewModel, bool>(
              selector: (context, vm) => vm.isInitialized,
              builder: (context, isInitialized, child) {
                return FutureBuilder(
                  future: isInitialized ? null : vm.initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }

                    if (snapshot.hasError) {
                      return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
                    }

                    return _buildInitializedContent(context);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitializedContent(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScenesViewModel>(
          create: (context) => ScenesViewModel(
            context.read<EventBus>(),
            context.read<SceneManager>(),
            context.read<DeviceManager>(),
            context.read<RoutineManager>(),
            context.read<IAppNotificationService>(),
            logger: context.read<Logger>(),
          ),
          lazy: true,
        ),
        ChangeNotifierProvider(create: (_) => MyViewModel(), lazy: true),
        ChangeNotifierProvider(
          create: (context) {
            final logger = context.read<Logger>();
            final globalEventBus = context.read<EventBus>();
            final sm = context.read<SceneManager>();
            final gm = context.read<GroupManager>();
            final dm = context.read<DeviceManager>();
            final dmr = context.read<IDeviceModuleRegistry>();
            return GroupedDevicesViewModel(globalEventBus, sm, gm, dm, dmr, logger: logger);
          },
          lazy: true,
        ),
      ],
      child: buildScaffold(context),
    );
  }
}
