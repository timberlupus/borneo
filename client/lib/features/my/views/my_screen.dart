import 'package:flutter/cupertino.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';

import 'package:borneo_app/features/my/views/about_screen.dart';
import 'package:borneo_app/features/settings/views/app_settings_screen.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  List<Widget> buildItems(BuildContext context) {
    return <Widget>[
      const SizedBox(height: 16),

      // Settings tile
      ListTile(
        title: Text(context.translate('Settings')),
        leading: Icon(Icons.settings_outlined),
        trailing: const CupertinoListTileChevron(),
        tileColor: Theme.of(context).colorScheme.surfaceContainer,
        onTap: () {
          final route = MaterialPageRoute(builder: (context) => AppSettingsScreen());
          Navigator.push(context, route);
        },
      ),

      // About tile
      ListTile(
        title: Text(context.translate('About')),
        leading: Icon(Icons.info_outline),
        trailing: const CupertinoListTileChevron(),
        tileColor: Theme.of(context).colorScheme.surfaceContainer,
        onTap: () {
          Future.delayed(Duration(milliseconds: 300), () {
            final route = MaterialPageRoute(builder: (context) => AboutScreen());
            if (context.mounted) {
              Navigator.push(context, route);
            }
          });
        },
      ),
      // divider
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = buildItems(context);
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: false,
          snap: false,
          floating: false,
          expandedHeight: 160,
          foregroundColor: Colors.white,
          backgroundColor: Color.fromARGB(0xff, 0x3e, 0x36, 0x58),
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Image.asset('assets/images/main-logo.png', height: 80), const SizedBox(height: 8)],
            ),
            centerTitle: true,
          ),
        ),
        SliverList.separated(
          itemCount: items.length,
          itemBuilder: (context, index) => items[index],
          separatorBuilder: (context, index) {
            return Divider(height: 1, color: Theme.of(context).scaffoldBackgroundColor);
          },
        ),
      ],
    );
  }
}
