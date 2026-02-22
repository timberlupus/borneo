import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import '../../../core/services/scene_manager.dart';
import '../../../core/services/app_notification_service.dart';
import '../models/scene_edit_arguments.dart';
import '../view_models/scene_edit_view_model.dart';
import '../../../shared/widgets/confirmation_sheet.dart';

class SceneEditScreen extends StatefulWidget {
  final SceneEditArguments args;
  const SceneEditScreen({required this.args, super.key});
  @override
  State<SceneEditScreen> createState() => _SceneEditScreenState();
}

class _SceneEditScreenState extends State<SceneEditScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SceneEditViewModel>(
      create: (ctx) =>
          SceneEditViewModel(ctx.read<ISceneManager>(), isCreation: widget.args.isCreation, model: widget.args.model),
      child: Builder(
        builder: (context) {
          final vm = context.watch<SceneEditViewModel>();
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.args.isCreation ? context.translate('New Scene') : context.translate('Edit Scene')),
              backgroundColor: Theme.of(context).colorScheme.surface,
              actions: _buildActions(context, vm),
            ),
            body: _buildBody(context, vm),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, SceneEditViewModel vm) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildImageSection(context, vm),
            const SizedBox(height: 16),
            _buildNameField(context, vm),
            const SizedBox(height: 16),
            _buildNotesField(context, vm),
            const SizedBox(height: 24),
            _buildSubmitButton(context, vm),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, SceneEditViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.translate('Scene Image'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickImage(vm, Theme.of(context)),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: vm.imagePath != null && vm.imagePath!.isNotEmpty && File(vm.imagePath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(vm.imagePath!), fit: BoxFit.cover, width: double.infinity, height: 120),
                      )
                    : Center(child: Icon(Icons.add_a_photo_outlined, size: 40, color: Theme.of(context).hintColor)),
              ),
            ),
            if (vm.imagePath != null && vm.imagePath!.isNotEmpty && File(vm.imagePath!).existsSync())
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => vm.setImagePath(null),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNameField(BuildContext context, SceneEditViewModel vm) {
    return TextFormField(
      initialValue: vm.name,
      decoration: InputDecoration(
        labelText: context.translate('Name'),
        hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
        hintText: context.translate('Enter the required scene name'),
      ),
      key: const Key('field_scene_name'),
      validator: (value) {
        if (value?.trim().isEmpty ?? true) {
          return context.translate('Please enter the scene name');
        }
        return null;
      },
      onSaved: (value) {
        vm.updateName(value ?? '');
      },
    );
  }

  Widget _buildNotesField(BuildContext context, SceneEditViewModel vm) {
    return TextFormField(
      initialValue: vm.notes,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
        hintText: context.translate('Enter the optional notes for this scene'),
        labelText: context.translate('Notes'),
      ),
      key: const Key('field_scene_notes'),
      onSaved: (value) {
        vm.updateNotes(value ?? '');
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context, SceneEditViewModel vm) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: vm.isLoading
            ? null
            : () async {
                if (_formKey.currentState?.validate() ?? false) {
                  _formKey.currentState!.save();
                  final success = await vm.submit();
                  if (success) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                }
              },
        child: vm.isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(context.translate('Submit')),
        key: const Key('btn_submit'),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, SceneEditViewModel vm) {
    final notificationService = context.read<IAppNotificationService>();
    return [
      if (vm.deletionAvailable)
        IconButton(
          key: const Key('btn_delete_scene'),
          onPressed: vm.isLoading
              ? null
              : () async {
                  // reuse AsyncConfirmationSheet to expose known keys
                  final confirmed = await AsyncConfirmationSheet.show(
                    context,
                    message: context.translate(
                      'Are you sure you want to delete this scene? This action cannot be undone.',
                    ),
                  );
                  if (!confirmed) return;

                  final success = await vm.delete();
                  if (success) {
                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } else if (context.mounted) {
                    final error = vm.error;
                    switch (error) {
                      case 'last_scene':
                        notificationService.showWarning(
                          context.translate('Cannot Delete Scene'),
                          body: context.translate('Cannot delete the last remaining scene.'),
                        );
                        break;
                      case 'devices_or_groups':
                        notificationService.showWarning(
                          context.translate('Cannot Delete Scene'),
                          body: context.translate(
                            'This scene contains devices or device groups. Please remove all devices and groups from this scene before deleting it.',
                          ),
                        );
                        break;
                    }
                  }
                },
          icon: const Icon(Icons.delete_outline),
        ),
    ];
  }

  Future<void> _pickImage(SceneEditViewModel vm, ThemeData theme) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (!kIsWeb && Platform.isWindows) {
        vm.setImagePath(picked.path);
      } else {
        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: theme.colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.ratio16x9,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
              ],
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioPresets: [
                CropAspectRatioPreset.ratio16x9,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
              ],
            ),
          ],
        );
        if (cropped != null) {
          vm.setImagePath(cropped.path);
        }
      }
    }
  }
}
