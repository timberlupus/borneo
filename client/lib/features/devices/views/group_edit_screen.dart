import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/features/devices/view_models/group_edit_view_model.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/shared/widgets/confirmation_sheet.dart';

class GroupEditScreen extends StatefulWidget {
  const GroupEditScreen({super.key});

  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Widget> makePropertyTiles(BuildContext context) {
    final vm = context.read<GroupEditViewModel>();
    return [
      TextFormField(
        key: const Key('field_group_name'),
        controller: _nameController,
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
        controller: _notesController,
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
      Selector<GroupEditViewModel, bool>(
        selector: (_, vm) => vm.isBusy,
        builder: (context, isBusy, _) {
          final vm = context.read<GroupEditViewModel>();
          return ElevatedButton(
            key: const Key('btn_submit'),
            onPressed: isBusy ? null : () => _onSubmitPressed(context, vm),
            child: isBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.translate('Submit')),
          );
        },
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
          if (!_controllersInitialized) {
            final vm = context.read<GroupEditViewModel>();
            _nameController.text = vm.name;
            _notesController.text = vm.notes;
            _controllersInitialized = true;
          }
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
              key: const Key('btn_delete_group'),
              onPressed: () async {
                final vm = context.read<GroupEditViewModel>();
                final notificationService = context.read<IAppNotificationService>();
                final navigator = Navigator.of(context);

                // show confirmation using a bottom sheet instead of an alert dialog
                final confirmed = await AsyncConfirmationSheet.show(
                  context,
                  message: context.translate(
                    'Are you sure you want to delete "{0}" group?\n\nDevices in this group will be moved to the "Ungrouped" area.',
                    pArgs: [vm.name],
                  ),
                );

                if (confirmed) {
                  // Show loading indicator on the same (tab) navigator so the
                  // sheet doesn’t get orphaned when we pop the edit screen.
                  if (context.mounted) {
                    final loadingContext = context;
                    final loadingNavigator = Navigator.of(loadingContext, rootNavigator: false);
                    showDialog(
                      context: loadingContext,
                      useRootNavigator: false,
                      barrierDismissible: false,
                      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      await vm.delete();
                      if (loadingContext.mounted) {
                        loadingNavigator.pop(); // Close loading dialog
                        // Pop the edit screen only if there's something to pop.
                        if (navigator.mounted && navigator.canPop()) {
                          navigator.pop(true); // Return success
                        }
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
              },
              icon: const Icon(Icons.delete_outline),
            );
          },
        ),
    ];
  }

  // Private helpers for the submit button logic --------------------------------

  bool _validateAndSave() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();
      return true;
    }
    return false;
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _onSubmitSuccess(NavigatorState navigator) {
    if (navigator.mounted) {
      navigator.pop();
      navigator.pop(true);
    }
  }

  void _onSubmitError(
    Object error,
    NavigatorState navigator,
    IAppNotificationService notificationService,
    String failureText,
  ) {
    if (navigator.mounted) {
      navigator.pop();
      notificationService.showError(failureText, body: error.toString());
    }
  }

  void _onSubmitPressed(BuildContext context, GroupEditViewModel vm) {
    if (!_validateAndSave()) return;

    final navigator = Navigator.of(context);
    final notificationService = context.read<IAppNotificationService>();
    final failureText = context.translate('Operation failed');

    _showLoadingDialog(context);

    vm.submit().then((_) => _onSubmitSuccess(navigator)).catchError((error) {
      _onSubmitError(error, navigator, notificationService, failureText);
    });
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
