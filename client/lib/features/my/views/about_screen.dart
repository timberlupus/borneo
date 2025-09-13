import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/url_launcher_service.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/my/view_models/about_view_model.dart';

final Uri _websiteUrl = Uri.parse('https://www.borneoiot.com');
final Uri _docsUrl = Uri.parse('https://docs.borneoiot.com');

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchWebsite(BuildContext context) async {
    final urlLauncher = UrlLauncherService(notification: Provider.of<IAppNotificationService>(context, listen: false));
    await urlLauncher.open(_websiteUrl.toString());
  }

  Future<void> _launchDocs(BuildContext context) async {
    final urlLauncher = UrlLauncherService(notification: Provider.of<IAppNotificationService>(context, listen: false));
    await urlLauncher.open(_docsUrl.toString());
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<AboutViewModel>(
    create: (_) => AboutViewModel()..initialize(),
    builder: (context, child) {
      return buildBody(context);
    },
  );

  Widget buildBody(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: false,
            snap: false,
            floating: false,
            expandedHeight: 200,
            foregroundColor: Colors.white,
            backgroundColor: Color.fromARGB(0xff, 0x3e, 0x36, 0x58),
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.0,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/main-logo.png', height: 80),
                  const SizedBox(height: 8),
                  Consumer<AboutViewModel>(
                    builder: (context, vm, child) => vm.isInitialized
                        ? Text(
                            vm.packageInfo.appName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                          )
                        : Container(),
                  ),
                  Consumer<AboutViewModel>(
                    builder: (context, vm, child) => vm.isInitialized
                        ? Text(
                            context.translate(
                              'Version: {verText} Build: {buildNumberText}',
                              nArgs: {
                                'verText': vm.packageInfo.version.toString(),
                                'buildNumberText': vm.packageInfo.buildNumber.toString(),
                              },
                            ),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white30),
                          )
                        : Container(),
                  ),
                ],
              ),
              centerTitle: true,
            ),
          ),

          // Copyrights info
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Center(
                child: Text(
                  context.translate('Copyright © Yunnan BinaryStars Technologies, Co., Ltd. All rights reserved.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),

          // Home page
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Material(
                child: Center(
                  child: Column(
                    children: [
                      Text(context.translate('Website'), style: Theme.of(context).textTheme.titleSmall),
                      InkWell(
                        onTap: () async {
                          await _launchWebsite(context);
                        },
                        child: Ink(
                          child: Text(
                            _websiteUrl.host,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Docs
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Material(
                child: Center(
                  child: Column(
                    children: [
                      Text(context.translate('Documentation'), style: Theme.of(context).textTheme.titleSmall),
                      InkWell(
                        onTap: () async {
                          await _launchDocs(context);
                        },
                        child: Ink(
                          child: Text(
                            _docsUrl.host,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Warning
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                context.translate(
                  '''This mobile application is free software licensed under GNU General Public License version 3 or later, with no warranty.
The author assumes no responsibility or liability for any direct or indirect consequences resulting from the use of this software.''',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
