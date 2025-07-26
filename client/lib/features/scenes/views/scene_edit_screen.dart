import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/features/scenes/providers/scene_edit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../shared/widgets/confirmation_sheet.dart';

class SceneEditScreen extends ConsumerStatefulWidget {
  final SceneEditArguments args;

  const SceneEditScreen({required this.args, super.key});

  @override
  ConsumerState<SceneEditScreen> createState() => _SceneEditScreenState();
}

class _SceneEditScreenState extends ConsumerState<SceneEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final StateNotifierProvider<SceneEditNotifier, SceneEditState> _sceneEditProvider;
  @override
  void initState() {
    super.initState();
    // 创建一个稳定的 provider 实例
    _sceneEditProvider = StateNotifierProvider<SceneEditNotifier, SceneEditState>((ref) {
      return SceneEditNotifier(
        ref.watch(_sceneManagerProvider),
        isCreation: widget.args.isCreation,
        model: widget.args.model,
      );
    }, dependencies: [_sceneManagerProvider]);
  }

  // 临时的 SceneManager provider，用于桥接
  late final Provider<ISceneManager> _sceneManagerProvider = Provider<ISceneManager>((ref) {
    throw UnimplementedError('SceneManager must be provided by context');
  });

  @override
  Widget build(BuildContext context) {
    return provider.Consumer<ISceneManager>(
      builder: (context, sceneManager, child) {
        return ProviderScope(
          overrides: [_sceneManagerProvider.overrideWithValue(sceneManager)],
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(_sceneEditProvider);
              final notifier = ref.read(_sceneEditProvider.notifier);

              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    widget.args.isCreation ? context.translate('New Scene') : context.translate('Edit Scene'),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  actions: _buildActions(context, ref, state, notifier),
                ),
                body: _buildBody(context, ref, state, notifier),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, SceneEditState state, SceneEditNotifier notifier) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildImageSection(context, state, notifier),
            const SizedBox(height: 16),
            _buildNameField(context, state, notifier),
            const SizedBox(height: 16),
            _buildNotesField(context, state, notifier),
            const SizedBox(height: 24),
            _buildSubmitButton(context, state, notifier),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, SceneEditState state, SceneEditNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.translate('Scene Image'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickImage(notifier, Theme.of(context)),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: state.imagePath != null && state.imagePath!.isNotEmpty && File(state.imagePath!).existsSync()
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(state.imagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 120,
                        ),
                      )
                    : Center(child: Icon(Icons.add_a_photo_outlined, size: 40, color: Theme.of(context).hintColor)),
              ),
            ),
            if (state.imagePath != null && state.imagePath!.isNotEmpty && File(state.imagePath!).existsSync())
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => notifier.setImagePath(null),
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

  Widget _buildNameField(BuildContext context, SceneEditState state, SceneEditNotifier notifier) {
    return TextFormField(
      initialValue: state.name,
      decoration: InputDecoration(
        labelText: context.translate('Name'),
        hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
        hintText: context.translate('Enter the required scene name'),
      ),
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return context.translate('Please enter the scene name');
        }
        return null;
      },
      onSaved: (value) {
        notifier.updateName(value ?? '');
      },
    );
  }

  Widget _buildNotesField(BuildContext context, SceneEditState state, SceneEditNotifier notifier) {
    return TextFormField(
      initialValue: state.notes,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintStyle: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
        hintText: context.translate('Enter the optional notes for this scene'),
        labelText: context.translate('Notes'),
      ),
      onSaved: (value) {
        notifier.updateNotes(value ?? '');
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context, SceneEditState state, SceneEditNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: state.isLoading
            ? null
            : () async {
                if (_formKey.currentState?.validate() ?? false) {
                  _formKey.currentState!.save();
                  final success = await notifier.submit();
                  if (success) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                }
              },
        child: state.isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(context.translate('Submit')),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref, SceneEditState state, SceneEditNotifier notifier) {
    return [
      if (notifier.deletionAvailable)
        IconButton(
          onPressed: state.isLoading
              ? null
              : () {
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return ConfirmationSheet(
                        message: context.translate(
                          'Are you sure you want to delete this device group? The devices within this group will not be deleted but will be moved to the "Ungrouped" group.',
                        ),
                        okPressed: () async {
                          final success = await notifier.delete();
                          if (success) {
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          }
                        },
                      );
                    },
                  );
                },
          icon: const Icon(Icons.delete_outline),
        ),
    ];
  }

  Future<void> _pickImage(SceneEditNotifier notifier, ThemeData theme) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      if (!kIsWeb && Platform.isWindows) {
        notifier.setImagePath(picked.path);
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
          notifier.setImagePath(cropped.path);
        }
      }
    }
  }
}
