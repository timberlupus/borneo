import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/url_launcher_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart' as provider;
import 'package:url_launcher/url_launcher.dart';

import '../providers/my_providers.dart';

final Uri _websiteUrl = Uri.parse('https://www.borneoiot.com');
final Uri _docsUrl = Uri.parse('https://docs.borneoiot.com');

class AboutScreenRiverpod extends ConsumerWidget {
  AboutScreenRiverpod({super.key});
  late final UrlLauncherService _urlLauncher;

  Future<void> _launchWebsite() async {
    if (!await launchUrl(_websiteUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $_websiteUrl');
    }
  }

  Future<void> _launchDocs() async {
    if (!await launchUrl(_docsUrl, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $_docsUrl');
    }
  }

  Future<bool> _canLaunchUrl(Uri url) async {
    return await canLaunchUrl(url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            snap: false,
            floating: false,
            expandedHeight: 200,
            foregroundColor: Colors.white,
            backgroundColor: const Color.fromARGB(0xff, 0x3e, 0x36, 0x58),
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1.0,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/main-logo.png', height: 80),
                  const SizedBox(height: 8),
                  packageInfoAsync.when(
                    data: (info) => Text(
                      info.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                  packageInfoAsync.when(
                    data: (info) => Text(
                      context.translate(
                        'Version: {verText} Build: {buildNumberText}',
                        nArgs: {'verText': info.version.toString(), 'buildNumberText': info.buildNumber.toString()},
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white30),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
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
                  context.translate('Copyright © Li Wei. All rights reserved.'),
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
                          if (await _canLaunchUrl(_websiteUrl)) {
                            await _launchWebsite();
                          }
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
                          if (await _canLaunchUrl(_docsUrl)) {
                            await _launchDocs();
                          }
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
