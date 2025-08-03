import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class DeviceGroupSelectionSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final void Function(DeviceGroupEntity? group) onTapGroup;
  final List<DeviceGroupEntity> availableGroups;
  final String? excludeGroupId;
  const DeviceGroupSelectionSheet({
    required this.availableGroups,
    required this.onTapGroup,
    required this.title,
    this.subtitle,
    this.excludeGroupId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final filteredGroups = availableGroups.where((g) => g.id != excludeGroupId).toList();

    final tiles =
        <Widget>[
              ListTile(
                title: Text(context.translate('No group')),
                onTap: () {
                  Navigator.pop(context);
                  onTapGroup(null);
                },
              ),
            ]
            .followedBy(
              filteredGroups.map((g) {
                return ListTile(
                  dense: true,
                  title: Text(g.name),
                  onTap: () {
                    Navigator.pop(context);
                    onTapGroup(g);
                  },
                );
              }),
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, textAlign: TextAlign.center),
        ),
        if (subtitle != null)
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              subtitle!,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
        const SizedBox(height: 8),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: ListView.separated(
            padding: const EdgeInsets.all(0),
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) => tiles[index],
            separatorBuilder: (BuildContext context, int index) => const Divider(indent: 16, height: 8, thickness: 1),
            itemCount: tiles.length,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
