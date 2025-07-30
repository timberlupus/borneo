import 'package:borneo_common/exceptions.dart';

/// Exception thrown when trying to delete the last remaining scene
class CannotDeleteLastSceneException extends InvalidOperationException {
  CannotDeleteLastSceneException() : super(message: 'Cannot delete the last remaining scene.');
}

/// Exception thrown when trying to delete a scene that contains devices or groups
class SceneContainsDevicesOrGroupsException extends InvalidOperationException {
  SceneContainsDevicesOrGroupsException()
    : super(message: 'Cannot delete scene with devices or device groups. Please remove them first.');
}
