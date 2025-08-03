import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:borneo_app/features/devices/view_models/device_discovery_view_model.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:logger/logger.dart';

// Mock classes for testing
class MockLogger extends Mock implements Logger {}

class MockGroupManager extends Mock implements IGroupManager {}

class MockDeviceManager extends Mock implements IDeviceManager {}

class MockDeviceModuleRegistry extends Mock implements IDeviceModuleRegistry {}

void main() {
  late DeviceDiscoveryViewModel viewModel;
  late MockLogger mockLogger;
  late MockGroupManager mockGroupManager;
  late MockDeviceManager mockDeviceManager;
  late MockDeviceModuleRegistry mockDeviceModuleRegistry;

  setUp(() {
    mockLogger = MockLogger();
    mockGroupManager = MockGroupManager();
    mockDeviceManager = MockDeviceManager();
    mockDeviceModuleRegistry = MockDeviceModuleRegistry();

    viewModel = DeviceDiscoveryViewModel(
      mockLogger,
      mockGroupManager,
      mockDeviceManager,
      mockDeviceModuleRegistry,
      globalEventBus: null,
    );
  });

  group('DeviceDiscoveryViewModel Tests', () {
    test('initial state is correct', () {
      expect(viewModel.isDiscovering, isFalse);
      expect(viewModel.discoveredDevices.value, isEmpty);
      expect(viewModel.isSmartConfigEnabled, isFalse);
      expect(viewModel.isFormValid, isTrue);
    });

    test('toggleSmartConfigSwitch updates state', () {
      // Act
      viewModel.toggleSmartConfigSwitch(true);

      // Assert
      expect(viewModel.isSmartConfigEnabled, isTrue);
    });

    test('ssid setter updates and validates form', () {
      // Act
      viewModel.ssid = 'TestNetwork';

      // Assert
      expect(viewModel.ssid, 'TestNetwork');
    });

    test('password setter updates and validates form', () {
      // Act
      viewModel.password = 'testpass123';

      // Assert
      expect(viewModel.password, 'testpass123');
    });

    test('startDiscovery sets isBusy to true', () async {
      // Arrange
      when(mockDeviceManager.startDiscovery()).thenAnswer((_) async => null);
      when(mockDeviceManager.isDiscoverying).thenReturn(false);

      // Act
      viewModel.startDiscovery();

      // Assert
      expect(viewModel.isBusy, isTrue);
    });

    test('stopDiscovery handles stop correctly', () async {
      // Arrange
      when(mockDeviceManager.stopDiscovery()).thenAnswer((_) async => null);
      when(mockDeviceManager.isDiscoverying).thenReturn(true);

      // Act
      viewModel.stopDiscovery();

      // Assert
      expect(viewModel.isBusy, isTrue);
    });

    test('clearAddedDevice resets latest device', () {
      // Act
      viewModel.clearAddedDevice();

      // Assert
      expect(viewModel.lastestAddedDevice, isNull);
    });

    test('dispose cleans up resources', () async {
      // Arrange
      when(mockDeviceManager.isDiscoverying).thenReturn(false);

      // Act
      viewModel.dispose();

      // Assert
      expect(() => viewModel.dispose(), returnsNormally);
    });
  });
}
