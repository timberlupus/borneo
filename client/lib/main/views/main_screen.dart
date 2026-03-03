import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/features/devices/providers/group_edit_provider.dart';
import 'package:borneo_app/routes/app_routes.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/features/scenes/models/scene_edit_arguments.dart';
import 'package:borneo_app/features/scenes/views/scenes_screen.dart';
import 'package:borneo_app/features/devices/views/group_edit_screen.dart';
import 'package:borneo_app/features/scenes/views/scene_edit_screen.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../core/services/devices/device_manager.dart';
import '../../core/services/scene_manager.dart';
import '../../features/devices/view_models/grouped_devices_view_model.dart';
import '../../features/my/providers/my_provider.dart';
import '../../features/devices/views/devices_screen.dart';
import '../../features/my/views/my_screen.dart';

import '../view_models/main_view_model.dart';
import '../../routes/route_manager.dart';

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
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupEditScreen(),
        settings: RouteSettings(arguments: GroupEditArguments(isCreation: true)),
      ),
    );
    // Refresh the device list when a group was successfully created.
    if (result == true && context.mounted) {
      context.read<GroupedDevicesViewModel>().refresh();
    }
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
            key: const Key('menu_item_add_group'),
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
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // controller for persistent_bottom_nav_bar package
  late final PersistentTabController _persistentController;

  // One GlobalKey per tab so we can interrogate each tab's Navigator state
  // and manually pop sub-pages when the Android back button is pressed.
  final List<GlobalKey<NavigatorState>> _tabNavKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _persistentController = PersistentTabController(initialIndex: 0);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget buildScaffold(BuildContext context) {
    final mainVM = context.read<MainViewModel>();
    final routeManager = context.read<RouteManager>();

    List<Widget> buildScreens() => const [
      ProvideScenesViewModel(child: ScenesScreen(key: ValueKey('scenes'))),
      DevicesScreen(key: ValueKey('devices')),
      MyScreen(key: ValueKey('my')),
    ];

    // Each tab needs its own RouteAndNavigatorSettings so that
    // Navigator.of(context).pushNamed(...) calls inside tabs can resolve
    // named routes (device detail pages, discovery screen, etc.).
    // We also pass individual GlobalKeys so the outer PopScope can check
    // whether a tab's navigator can pop before running the exit logic.
    RouteAndNavigatorSettings tabNavSettings(int index) =>
        RouteAndNavigatorSettings(onGenerateRoute: routeManager.onGenerateRoute, navigatorKey: _tabNavKeys[index]);

    List<PersistentBottomNavBarItem> navBarItems() => [
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.house),
        inactiveIcon: const Icon(Icons.house_outlined),
        title: context.translate('Scenes'),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurface,
        routeAndNavigatorSettings: tabNavSettings(0),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.device_hub),
        inactiveIcon: const Icon(Icons.device_hub_outlined),
        title: context.translate('Devices'),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurface,
        routeAndNavigatorSettings: tabNavSettings(1),
      ),
      PersistentBottomNavBarItem(
        icon: const Icon(Icons.person),
        inactiveIcon: const Icon(Icons.person_outline),
        title: context.translate('My'),
        activeColorPrimary: Theme.of(context).colorScheme.primary,
        inactiveColorPrimary: Theme.of(context).colorScheme.onSurface,
        routeAndNavigatorSettings: tabNavSettings(2),
      ),
    ];

    return Selector<MainViewModel, TabIndices>(
      selector: (context, vm) => vm.currentTabIndex,
      builder: (context, tabIndex, child) {
        // keep controller in sync with view model state
        if (_persistentController.index != tabIndex.index) {
          _persistentController.jumpToTab(tabIndex.index);
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness,
          ),
          child: PersistentTabView(
            context,
            controller: _persistentController,
            screens: buildScreens(),
            items: navBarItems(),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            //Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
            //Theme.of(context).colorScheme.surfaceContainerHighest,
            // Back-button handling is fully managed by the outer PopScope
            // with per-tab navigator-key checks, so we disable the built-in
            // handler to avoid double-handling.
            handleAndroidBackButtonPress: false,
            resizeToAvoidBottomInset: true,
            onItemSelected: (index) {
              if (index != tabIndex.index) {
                mainVM.setIndex(TabIndices.values[index]);
              }
            },
            navBarStyle: NavBarStyle.style1,
          ),
        );
      },
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
            content: Row(
              children: [CircularProgressIndicator(), SizedBox(width: 20), Text(context.translate('Loading...'))],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(context);
                },
                child: Text(context.translate('Cancel')),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gt = GettextLocalizations.of(context);
    return ChangeNotifierProvider(
      create: (ctx) {
        final bus = ctx.read<EventBus>();
        final bm = ctx.read<IBlobManager>();
        final sm = ctx.read<ISceneManager>();
        final gm = ctx.read<IGroupManager>();
        final dm = ctx.read<IDeviceManager>();
        final ls = ctx.read<ILocaleService>();
        final notification = ctx.read<IAppNotificationService>();
        final logger = ctx.read<Logger>();
        final clock = ctx.read<IClock>();
        final vm = MainViewModel(
          bus,
          bm,
          sm,
          gm,
          dm,
          ls,
          notification: notification,
          clock: clock,
          gt: gt,
          logger: logger,
        );

        if (vm.initFuture != null) {
          vm.initFuture!
              .catchError((error, stack) {
                vm.logger?.e('App init failed', error: error, stackTrace: stack);
                notification.showError(gt.translate('Editor initialization failed. Please retry.'));
              })
              .whenComplete(() => FlutterNativeSplash.remove());
        } else {
          FlutterNativeSplash.remove();
        }
        return vm;
      },
      lazy: false,
      child: Builder(
        builder: (context) {
          final vm = context.read<MainViewModel>();

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;

              // If the current tab's inner Navigator has pages above root,
              // pop those first – no exit prompt in that case.
              final tabNavState = _tabNavKeys[_persistentController.index].currentState;
              if (tabNavState != null && tabNavState.canPop()) {
                tabNavState.pop();
                return;
              }

              // We're at the navigation root: apply double-back-to-exit.
              final shouldPop = await vm.handleWillPop();
              if (!shouldPop) {
                if (context.mounted) {
                  provider.Provider.of<IAppNotificationService>(
                    context,
                    listen: false,
                  ).showInfo(context.translate('Press back again to exit'));
                }
              } else if (context.mounted) {
                SystemNavigator.pop();
              }
            },
            child: Selector<MainViewModel, bool>(
              selector: (context, vm) => vm.isInitialized,
              builder: (context, isInitialized, _) {
                return isInitialized ? _buildInitializedContent(context) : const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitializedContent(BuildContext context) {
    final gt = GettextLocalizations.of(context);
    // override the Riverpod provider for MyViewModel using the current
    // localization instance.  downstream widgets can read it via
    // `ref.watch(myViewModelProvider)` once they have been migrated.
    return ProviderScope(
      overrides: [myViewModelProvider.overrideWithValue(MyViewModel(gt: gt))],
      child: MultiProvider(
        providers: [
          // MyViewModel is now supplied by Riverpod; we leave the other
          // ChangeNotifierProviders unchanged until they're migrated.
          ChangeNotifierProvider(
            create: (context) {
              final logger = context.read<Logger>();
              final globalEventBus = context.read<EventBus>();
              final sm = context.read<ISceneManager>();
              final gm = context.read<IGroupManager>();
              final dm = context.read<IDeviceManager>();
              final dmr = context.read<IDeviceModuleRegistry>();
              final clock = context.read<IClock>();
              return GroupedDevicesViewModel(
                globalEventBus,
                sm,
                gm,
                dm,
                dmr,
                clock: clock,
                gt: context.read<GettextLocalizations>(),
                logger: logger,
              );
            },
            lazy: false,
          ),
        ],
        child: buildScaffold(context),
      ),
    );
  }
}
