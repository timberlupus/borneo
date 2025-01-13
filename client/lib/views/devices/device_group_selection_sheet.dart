import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:flutter/material.dart';

class DeviceGroupSelectionSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final void Function(DeviceGroupEntity? group) onTapGroup;
  final List<DeviceGroupEntity> availableGroups;
  const DeviceGroupSelectionSheet({
    required this.availableGroups,
    required this.onTapGroup,
    required this.title,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      ListTile(
        title: Text('No group'),
        onTap: () {
          Navigator.pop(context);
          onTapGroup(null);
        },
      )
    ].followedBy(availableGroups.map((g) {
      return ListTile(
        dense: true,
        title: Text(g.name),
        onTap: () {
          Navigator.pop(context);
          onTapGroup(g);
        },
      );
    })).toList();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title, textAlign: TextAlign.center)),
          if (subtitle != null)
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                subtitle!,
                textAlign: TextAlign.start,
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(color: Theme.of(context).hintColor),
              ),
            ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) => tiles[index],
            separatorBuilder: (BuildContext context, int index) => Divider(
              indent: 16,
              height: 16,
              thickness: 1,
            ),
            itemCount: tiles.length,
          ),
        ]);
  }
}
