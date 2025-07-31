import 'dart:io';
import 'dart:ui';

import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/routes/app_routes.dart';
import 'package:borneo_app/features/devices/view_models/group_edit_view_model.dart';
import 'package:borneo_app/features/devices/view_models/group_view_model.dart';
import 'package:borneo_app/features/devices/views/device_list_tile.dart';
import 'package:borneo_app/features/devices/view_models/grouped_devices_view_model.dart';
import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/widgets/empty_groups_widget.dart';
import 'group_edit_screen.dart';

class GroupSnapshot {
  final String id;
  final String name;
  final int deviceCount;
  final int lastModified;
  final bool isDummy;

  const GroupSnapshot({
    required this.id,
    required this.name,
    required this.deviceCount,
    required this.lastModified,
    required this.isDummy,
  });
}

enum PlusMenuIndexes { addGroup, addDevice }

class InGroupDeviceListView extends StatelessWidget {
  const InGroupDeviceListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<GroupViewModel, int>(
      selector: (_, gvm) => gvm.devices.length,
      shouldRebuild: (previous, current) => previous != current,
      builder: (context, deviceCount, child) {
        if (deviceCount == 0) return const SizedBox.shrink();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deviceCount,
          separatorBuilder: (context, index) => Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              children: [
                const SizedBox(width: 72), // 48 icon + 16 ListTile padding + 8
                Expanded(child: Divider(height: 1, thickness: 1, color: Theme.of(context).colorScheme.surface)),
              ],
            ),
          ),
          itemBuilder: (context, index) {
            return Selector<GroupViewModel, AbstractDeviceSummaryViewModel>(
              selector: (_, gvm) => gvm.devices[index],
              shouldRebuild: (previous, current) => previous != current,
              builder: (context, deviceVM, child) {
                return ChangeNotifierProvider.value(
                  key: ValueKey(deviceVM.deviceEntity.id),
                  value: deviceVM,
                  child: DeviceTile(index == deviceCount - 1),
                );
              },
            );
          },
        );
      },
    );
  }
}

class NoDataHintView extends StatelessWidget {
  const NoDataHintView({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyGroupsWidget(
        onCreateGroup: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupEditScreen(),
              settings: RouteSettings(arguments: GroupEditArguments(isCreation: true)),
            ),
          );
          // Refresh after creating group
          if (context.mounted) {
            context.read<GroupedDevicesViewModel>().refresh();
          }
        },
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  static const _smallShadow = Shadow(offset: Offset(1.0, 1.0), blurRadius: 2.0, color: Color.fromARGB(128, 0, 0, 0));

  Future<void> _showDiscoveryPage(BuildContext context) async {
    await Navigator.of(context).pushNamed(AppRoutes.kDeviceDiscovery);
  }

  Future<void> _showNewGroupScreen(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupEditScreen(),
        settings: RouteSettings(arguments: GroupEditArguments(isCreation: true)),
      ),
    );

    // Refresh if group was created
    if (result == true && context.mounted) {
      context.read<GroupedDevicesViewModel>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<GroupedDevicesViewModel>();
    return FutureBuilder(
      future: vm.initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(context.translate('Error: {errMsg}', nArgs: {'errMsg': snapshot.error.toString()})),
            ),
          );
        } else {
          return Scaffold(
            body: CustomScrollView(
              slivers: <Widget>[
                _buildAppBar(context),
                Selector<GroupedDevicesViewModel, List<GroupSnapshot>>(
                  selector: (_, vm) => vm.groups
                      .map(
                        (g) => GroupSnapshot(
                          id: g.id,
                          name: g.name,
                          deviceCount: g.devices.length,
                          lastModified: g.lastModified,
                          isDummy: g.isDummy,
                        ),
                      )
                      .toList(),
                  shouldRebuild: (previous, current) {
                    if (previous.length != current.length) return true;
                    for (var i = 0; i < previous.length; i++) {
                      if (previous[i].lastModified != current[i].lastModified) return true;
                    }
                    return false;
                  },
                  builder: (context, groupSnapshots, child) {
                    final groupedDevicesVM = context.read<GroupedDevicesViewModel>();
                    return groupedDevicesVM.isEmpty
                        ? const NoDataHintView()
                        : SliverList.builder(
                            itemCount: groupSnapshots.length,
                            itemBuilder: (context, index) {
                              final snapshot = groupSnapshots[index];
                              final gvm = groupedDevicesVM.groups.firstWhere((g) => g.id == snapshot.id);
                              return _buildGroupSection(context, gvm);
                            },
                          );
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }

  PopupMenuButton _buildAddButtons(BuildContext context) {
    return PopupMenuButton<PlusMenuIndexes>(
      icon: Icon(Icons.add_outlined, color: Colors.white, shadows: [_smallShadow]),
      onSelected: (value) {
        switch (value) {
          case PlusMenuIndexes.addDevice:
            {
              _showDiscoveryPage(context);
              break;
            }
          case PlusMenuIndexes.addGroup:
            {
              _showNewGroupScreen(context);
              break;
            }
        }
      },
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<PlusMenuIndexes>>[
          PopupMenuItem<PlusMenuIndexes>(
            value: PlusMenuIndexes.addDevice,
            child: Text(context.translate('Add New Devices')),
          ),
          PopupMenuItem<PlusMenuIndexes>(
            value: PlusMenuIndexes.addGroup,
            child: Text(context.translate('Add Devices Group')),
          ),
        ];
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Colors.white,
      title: Text(
        context.translate(
          'Devices in {currentScene}',
          nArgs: {'currentScene': context.read<GroupedDevicesViewModel>().currentScene.name},
        ),
        style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
          color: Colors.white,
          shadows: [const Shadow(blurRadius: 4.0, color: Colors.black, offset: Offset(2.0, 2.0))],
        ),
      ),
      actions: [_buildAddButtons(context)],
      //expandedHeight: MediaQuery.of(context).size.height / 8.0,
      flexibleSpace: FlexibleSpaceBar(
        expandedTitleScale: 1.0,
        background: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.7),
              ],
              stops: [0.0, 0.6, 0.8, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: context.read<GroupedDevicesViewModel>().currentScene.imagePath != null
                ? Image.file(
                    File(context.read<GroupedDevicesViewModel>().currentScene.imagePath!),
                    fit: BoxFit.cover,
                    height: double.infinity,
                    width: double.infinity,
                    alignment: Alignment.center,
                  )
                : Image.asset(
                    'assets/images/scenes/scene-default-noimage.jpg',
                    fit: BoxFit.cover,
                    height: double.infinity,
                    width: double.infinity,
                    alignment: Alignment.center,
                  ),
          ),
        ),
        stretchModes: [StretchMode.zoomBackground],
      ),
      pinned: true,
    );
  }

  Widget _buildGroupSection(BuildContext context, GroupViewModel g) {
    return ChangeNotifierProvider<GroupViewModel>.value(
      value: g,
      builder: (context, child) => Selector<GroupViewModel, ({String name, bool isEmpty, bool isDummy, bool isBusy})>(
        selector: (_, gvm) => (name: gvm.name, isEmpty: gvm.isEmpty, isDummy: gvm.isDummy, isBusy: gvm.isBusy),
        builder: (context, groupData, child) {
          if (groupData.isDummy && groupData.isEmpty) {
            return SizedBox(height: 0);
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  height: 32,
                  child: Row(
                    children: [
                      Text(groupData.name, textAlign: TextAlign.start, style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (!groupData.isDummy)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          constraints: null,
                          onPressed: groupData.isDummy || groupData.isBusy
                              ? null
                              : () => _showEditGroupPage(context, g.model),
                        ),
                    ],
                  ),
                ),
                const InGroupDeviceListView(),
              ],
            );
          }
        },
      ),
    );
  }

  void _showEditGroupPage(BuildContext context, DeviceGroupEntity group) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupEditScreen(),
        settings: RouteSettings(arguments: GroupEditArguments(isCreation: false, model: group)),
      ),
    );

    // Refresh if group was deleted or updated
    if (result == true && context.mounted) {
      context.read<GroupedDevicesViewModel>().refresh();
    }
  }
}
