import 'package:borneo_app/features/my/views/donation_screen.dart';
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

      // App Settings Card
      Card(
        elevation: 0.25,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              title: Text(context.translate('Settings')),
              leading: Icon(Icons.settings_outlined),
              trailing: const CupertinoListTileChevron(),
              onTap: () {
                final route = MaterialPageRoute(builder: (context) => AppSettingsScreen());
                Navigator.push(context, route);
              },
            ),
            ListTile(
              title: Text(context.translate('About')),
              leading: Icon(Icons.info_outline),
              trailing: const CupertinoListTileChevron(),
              onTap: () {
                final route = MaterialPageRoute(builder: (context) => AboutScreen());
                if (context.mounted) {
                  Navigator.push(context, route);
                }
              },
            ),
          ],
        ),
      ),

      const SizedBox(height: 8),

      // Support Card
      Card(
        elevation: 0.25,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          title: Text(context.translate('Back This Project')),
          leading: Icon(Icons.favorite_outline, color: Theme.of(context).colorScheme.error),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            final route = MaterialPageRoute(builder: (context) => DonationScreen());
            Navigator.push(context, route);
          },
        ),
      ),

      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = buildItems(context);
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
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
              children: [Image.asset('assets/images/main-logo.png', height: 90), const SizedBox(height: 8)],
            ),
            centerTitle: true,
          ),
        ),
        SliverList(delegate: SliverChildBuilderDelegate((context, index) => items[index], childCount: items.length)),
      ],
    );
  }
}
