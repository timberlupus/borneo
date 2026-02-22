import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';

import 'package:borneo_app/features/my/views/about_screen.dart';
import 'package:borneo_app/features/settings/views/app_settings_screen.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  /// Returns a sliver that contains the settings list.
  ///
  /// `SettingsList` itself is not a sliver and calling it directly inside
  /// [CustomScrollView.slivers] leads to a type mismatch (`RenderViewport
  /// expected a RenderSliver but received a RenderConstrainedBox`). Wrap the
  /// list in a [SliverToBoxAdapter] so it behaves correctly.
  Widget buildItems(BuildContext context) {
    // Use a SettingsList for consistency with other settings screens
    return SettingsList(
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      sections: [
        SettingsSection(
          tiles: [
            SettingsTile.navigation(
              leading: const Icon(Icons.settings_outlined),
              title: Text(context.translate('Settings')),
              onPressed: (bc) {
                final route = MaterialPageRoute(builder: (context) => AppSettingsScreen());
                Navigator.push(context, route);
              },
            ),
            SettingsTile.navigation(
              leading: const Icon(Icons.info_outline),
              title: Text(context.translate('About')),
              onPressed: (bc) {
                final route = MaterialPageRoute(builder: (context) => AboutScreen());
                if (context.mounted) {
                  Navigator.push(context, route);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use a regular Scaffold with a PreferredSize AppBar so we can specify
    // an arbitrary height for the header.  This removes the need for a
    // scrolling viewport while still leaving room for things like an avatar
    // or extra controls in the future.
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160), // match old expandedHeight
        child: AppBar(
          backgroundColor: const Color(0xff3e3658),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Image.asset('assets/images/main-logo.png', height: 90), const SizedBox(height: 8)],
            ),
          ),
          // toolbarHeight can also be used but PreferredSize gives full control
        ),
      ),
      body: buildItems(context),
    );
  }
}
