import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/url_launcher_service.dart';
import 'package:flutter_gettext/flutter_gettext.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/my/view_models/about_view_model.dart';

final Uri _websiteUrl = Uri.parse('https://www.borneoiot.com');
final Uri _docsUrl = Uri.parse('https://docs.borneoiot.com');
final Uri _privacyUrl = Uri.parse('https://www.borneoiot.com/app-privacy-policy/');

/// A reusable section displayed on the about screen with a title and a link.
///
/// The widget handles translation of the title and launching the provided URL
/// when tapped. It also shows the host portion of the URL with underline styling.
class _LinkSection extends StatelessWidget {
  // URI parsing is runtime, so constructor can't be const.
  const _LinkSection({required this.title, required this.url, this.hideLink = false});

  final String title; // Already translated by callers when needed
  final Uri url;
  final bool hideLink;

  @override
  Widget build(BuildContext context) {
    final titleText = context.translate(title);
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    final linkStyle = titleStyle?.copyWith(
      color: Theme.of(context).colorScheme.secondary,
      decoration: TextDecoration.underline,
    );

    Widget titleWidget;
    Widget? linkWidget;

    if (hideLink) {
      titleWidget = InkWell(
        onTap: () async {
          final urlLauncher = UrlLauncherService(
            notification: Provider.of<IAppNotificationService>(context, listen: false),
          );
          await urlLauncher.open(url.toString());
        },
        child: Text(titleText, style: linkStyle),
      );
    } else {
      titleWidget = Text(titleText, style: titleStyle);
      linkWidget = InkWell(
        onTap: () async {
          final urlLauncher = UrlLauncherService(
            notification: Provider.of<IAppNotificationService>(context, listen: false),
          );
          await urlLauncher.open(url.toString());
        },
        child: Text(url.host, style: linkStyle),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Material(
          child: Center(child: Column(children: [titleWidget, ?linkWidget])),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<AboutViewModel>(
    create: (_) => AboutViewModel(gt: GettextLocalizations.of(context))..initialize(),
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
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
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
                child: Column(
                  spacing: 4,
                  children: [
                    Text(
                      context.translate('Copyright © Yunnan BinaryStars Technologies, Co., Ltd.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(context.translate('All rights reserved.'), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),

          _LinkSection(title: context.translate('Website'), url: _websiteUrl),

          _LinkSection(title: context.translate('Documentation'), url: _docsUrl),

          _LinkSection(title: context.translate('Privacy Policy'), url: _privacyUrl, hideLink: true),

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
