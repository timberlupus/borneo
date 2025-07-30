import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import '../../settings/views/app_settings_screen_riverpod.dart';
import 'about_screen_riverpod.dart';
import 'donation_screen.dart';

class MyScreenRiverpod extends ConsumerWidget {
  const MyScreenRiverpod({super.key});

  List<Widget> _buildItems(BuildContext context, WidgetRef ref) {
    return [
      const SizedBox(height: 16),

      // Settings tile
      ListTile(
        title: Text(context.translate('Settings')),
        leading: const Icon(Icons.settings_outlined),
        trailing: const CupertinoListTileChevron(),
        tileColor: Theme.of(context).colorScheme.surfaceContainer,
        onTap: () {
          final route = MaterialPageRoute(builder: (context) => const AppSettingsScreenRiverpod());
          Navigator.push(context, route);
        },
      ),

      // Donation tile
      ListTile(
        title: Text(context.translate('Back This Project')),
        leading: const Icon(Icons.favorite_outline),
        trailing: const CupertinoListTileChevron(),
        tileColor: Theme.of(context).colorScheme.surfaceContainer,
        onTap: () {
          Future.delayed(const Duration(milliseconds: 300), () {
            final route = MaterialPageRoute(builder: (context) => const DonationScreen());
            if (context.mounted) {
              Navigator.push(context, route);
            }
          });
        },
      ),

      // About tile
      ListTile(
        title: Text(context.translate('About')),
        leading: const Icon(Icons.info_outline),
        trailing: const CupertinoListTileChevron(),
        tileColor: Theme.of(context).colorScheme.surfaceContainer,
        onTap: () {
          Future.delayed(const Duration(milliseconds: 300), () {
            final route = MaterialPageRoute(builder: (context) => AboutScreenRiverpod());
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
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _buildItems(context, ref);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          snap: false,
          floating: false,
          expandedHeight: 160,
          foregroundColor: Colors.white,
          backgroundColor: const Color.fromARGB(0xff, 0x3e, 0x36, 0x58),
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

class CupertinoListTileChevron extends StatelessWidget {
  const CupertinoListTileChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(CupertinoIcons.chevron_forward, size: 20, color: CupertinoColors.systemGrey.resolveFrom(context));
  }
}
