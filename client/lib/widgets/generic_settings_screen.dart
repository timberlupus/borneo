import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

class GenericSettingsScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? appBarActions;

  const GenericSettingsScreen({super.key, required this.children, this.title = 'Settings', this.appBarActions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.translate(title)), actions: appBarActions),
      body: ListView.builder(
        shrinkWrap: true,
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class GenericSettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const GenericSettingsGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final allChildren =
        <Widget>[
          ListTile(tileColor: Theme.of(context).scaffoldBackgroundColor, title: Text(context.translate(title))),
        ] +
        children;
    return Wrap(
      children: [
        ListView.separated(
          shrinkWrap: true,
          itemBuilder: (context, index) => allChildren[index],
          separatorBuilder: (context, index) => Divider(height: 0, color: Theme.of(context).scaffoldBackgroundColor),
          itemCount: allChildren.length,
        ),
      ],
    );
  }
}

class SaveButton extends StatelessWidget {
  const SaveButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(context.translate('Save')),
      onTap: () {
        // Save action
      },
    );
  }
}

class CancelButton extends StatelessWidget {
  const CancelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(context.translate('Cancel')),
      onTap: () {
        // Cancel action
      },
    );
  }
}
