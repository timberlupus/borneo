import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/features/scenes/providers/scene_edit_provider.dart';

import '../helpers/test_helpers.mocks.dart';

void main() {
  late SceneEditProvider viewModel;
  late MockSceneManager mockSceneManager;

  setUp(() {
    mockSceneManager = MockSceneManager();
    viewModel = SceneEditProvider(sceneManager: mockSceneManager);
  });

  group('SceneEditProvider Tests', () {
    test('initial state is correct', () {
      expect(viewModel.sceneName, isEmpty);
      expect(viewModel.selectedDevices, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasChanges, isFalse);
    });

    test('updateSceneName updates name and sets changes flag', () {
      // Act
      viewModel.updateSceneName('Living Room Scene');

      // Assert
      expect(viewModel.sceneName, 'Living Room Scene');
      expect(viewModel.hasChanges, isTrue);
    });

    test('addDevice adds device to selected devices', () {
      // Arrange
      final device = SceneDeviceEntity(
        deviceId: 'device-1',
        deviceName: 'LED Strip',
        brightness: 100,
        color: Colors.white,
      );

      // Act
      viewModel.addDevice(device);

      // Assert
      expect(viewModel.selectedDevices, hasLength(1));
      expect(viewModel.selectedDevices.first.deviceId, 'device-1');
      expect(viewModel.hasChanges, isTrue);
    });

    test('removeDevice removes device from selected devices', () {
      // Arrange
      final device = SceneDeviceEntity(
        deviceId: 'device-1',
        deviceName: 'LED Strip',
        brightness: 100,
        color: Colors.white,
      );
      viewModel.addDevice(device);

      // Act
      viewModel.removeDevice('device-1');

      // Assert
      expect(viewModel.selectedDevices, isEmpty);
      expect(viewModel.hasChanges, isTrue);
    });

    test('updateDeviceBrightness updates device brightness', () {
      // Arrange
      final device = SceneDeviceEntity(
        deviceId: 'device-1',
        deviceName: 'LED Strip',
        brightness: 50,
        color: Colors.white,
      );
      viewModel.addDevice(device);

      // Act
      viewModel.updateDeviceBrightness('device-1', 75);

      // Assert
      expect(viewModel.selectedDevices.first.brightness, 75);
      expect(viewModel.hasChanges, isTrue);
    });

    test('saveScene calls scene manager with correct data', () async {
      // Arrange
      viewModel.updateSceneName('Test Scene');
      viewModel.addDevice(
        SceneDeviceEntity(deviceId: 'device-1', deviceName: 'LED Strip', brightness: 100, color: Colors.white),
      );

      when(mockSceneManager.createScene(any)).thenAnswer((_) async => 'scene-123');

      // Act
      await viewModel.saveScene();

      // Assert
      verify(mockSceneManager.createScene(any)).called(1);
      expect(viewModel.isLoading, isFalse);
    });

    test('loadExistingScene populates data correctly', () async {
      // Arrange
      final existingScene = SceneEntity(
        id: 'scene-123',
        name: 'Existing Scene',
        devices: [SceneDeviceEntity(deviceId: 'device-1', deviceName: 'LED Strip', brightness: 80, color: Colors.blue)],
      );

      when(mockSceneManager.getScene('scene-123')).thenAnswer((_) async => existingScene);

      // Act
      await viewModel.loadExistingScene('scene-123');

      // Assert
      expect(viewModel.sceneName, 'Existing Scene');
      expect(viewModel.selectedDevices, hasLength(1));
      expect(viewModel.selectedDevices.first.deviceId, 'device-1');
      expect(viewModel.hasChanges, isFalse);
    });

    test('reset clears all data', () {
      // Arrange
      viewModel.updateSceneName('Test Scene');
      viewModel.addDevice(
        SceneDeviceEntity(deviceId: 'device-1', deviceName: 'LED Strip', brightness: 100, color: Colors.white),
      );

      // Act
      viewModel.reset();

      // Assert
      expect(viewModel.sceneName, isEmpty);
      expect(viewModel.selectedDevices, isEmpty);
      expect(viewModel.hasChanges, isFalse);
    });
  });
}
