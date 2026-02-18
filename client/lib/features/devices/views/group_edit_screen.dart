import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/features/devices/view_models/group_edit_view_model.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/devices/widgets/delete_group_dialog.dart';

class GroupEditScreen extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();

  GroupEditScreen({super.key});

  List<Widget> makePropertyTiles(BuildContext context) {
    final vm = context.read<GroupEditViewModel>();
    return [
      TextFormField(
        initialValue: vm.name,
        decoration: InputDecoration(
          labelText: context.translate('Name'),
          hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
          hintText: context.translate('Enter the required scene name'),
        ),
        validator: (value) {
          if (value?.isEmpty ?? false) {
            return context.translate('Please enter the scene name');
          }
          return null;
        },
        onSaved: (value) {
          vm.name = value ?? '';
        },
      ),
      SizedBox(height: 16),
      TextFormField(
        initialValue: vm.notes,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
          hintText: context.translate('Enter the optional notes for this scene'),
          labelText: context.translate('Notes'),
        ),
        onSaved: (value) {
          vm.notes = value ?? '';
        },
      ),
      SizedBox(height: 24),
      ElevatedButton(
        onPressed: vm.isBusy
            ? null
            : () {
                if (_formKey.currentState?.validate() ?? false) {
                  _formKey.currentState!.save();

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  final submitContext = context;
                  final navigator = Navigator.of(context);
                  final notificationService = context.read<IAppNotificationService>();

                  vm
                      .submit()
                      .then((_) {
                        if (submitContext.mounted) {
                          Navigator.pop(submitContext); // Close loading dialog
                          navigator.pop(true); // Return success
                        }
                      })
                      .catchError((error) {
                        if (submitContext.mounted) {
                          Navigator.pop(submitContext); // Close loading dialog
                          notificationService.showError(
                            submitContext.translate('Operation failed'),
                            body: error.toString(),
                          );
                        }
                      });
                }
              },
        child: vm.isBusy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(context.translate('Submit')),
      ),
    ];
  }

  ListView buildList(BuildContext context) {
    final items = makePropertyTiles(context);
    return ListView.builder(
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) => items[index],
      itemCount: items.length,
    );
  }

  FutureBuilder buildBody(BuildContext context) {
    final vm = context.read<GroupEditViewModel>();
    return FutureBuilder(
      future: vm.initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Form(key: _formKey, child: buildList(context)),
          );
        }
      },
    );
  }

  List<Widget> buildActions(BuildContext context, GroupEditArguments args) {
    return [
      if (!args.isCreation)
        Builder(
          builder: (BuildContext context) {
            return IconButton(
              onPressed: () {
                final vm = context.read<GroupEditViewModel>();
                final notificationService = context.read<IAppNotificationService>();
                final navigator = Navigator.of(context);

                showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => DeleteGroupDialog(groupName: vm.name),
                ).then((confirmed) async {
                  if (confirmed == true) {
                    // Show loading indicator
                    if (context.mounted) {
                      final loadingContext = context;
                      final loadingNavigator = Navigator.of(loadingContext);
                      showDialog(
                        context: loadingContext,
                        barrierDismissible: false,
                        builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        await vm.delete();
                        if (loadingContext.mounted) {
                          loadingNavigator.pop(); // Close loading dialog
                          navigator.pop(true); // Return success
                          notificationService.showSuccess(loadingContext.translate('Group deleted'));
                        }
                      } catch (error) {
                        if (loadingContext.mounted) {
                          loadingNavigator.pop(); // Close loading dialog
                          notificationService.showError(
                            loadingContext.translate('Delete failed'),
                            body: error.toString(),
                          );
                        }
                      }
                    }
                  }
                });
              },
              icon: const Icon(Icons.delete_outline),
            );
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final GroupEditArguments args = ModalRoute.of(context)!.settings.arguments as GroupEditArguments;
    final gt = GettextLocalizations.of(context);

    return ChangeNotifierProvider<GroupEditViewModel>(
      create: (context) => GroupEditViewModel(
        context.read<IGroupManager>(),
        isCreation: args.isCreation,
        model: args.model,
        globalEventBus: context.read<EventBus>(),
        gt: gt,
        logger: context.read<Logger>(),
      ),
      builder: (context, child) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            (ModalRoute.of(context)!.settings.arguments as GroupEditArguments).isCreation
                ? context.translate('New Device Group')
                : context.translate('Edit Device Group'),
          ),
          actions: buildActions(context, args),
        ),
        body: SafeArea(child: buildBody(context)),
      ),
    );
  }
}
