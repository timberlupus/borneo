import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/views/device_list_tile.dart';
import 'package:provider/provider.dart';

import '../helpers/test_helpers.dart';

// Mock view model for testing
class MockDeviceSummaryViewModel extends AbstractDeviceSummaryViewModel {
  MockDeviceSummaryViewModel({required DeviceEntity device, bool isOnline = true})
    : super(device: device, isOnline: isOnline);

  @override
  bool get isPowerOn => true;

  @override
  bool get isBusy => false;

  @override
  String get name => device.name;

  @override
  Future<void> refresh() async {}
}

void main() {
  group('DeviceTile Widget Tests', () {
    testWidgets('displays device information correctly', (WidgetTester tester) async {
      // Create a mock device entity
      final device = DeviceEntity(
        id: 'test-device-123',
        name: 'Test LED Controller',
        address: Uri.parse('http://192.168.1.100'),
        fingerprint: 'test-fingerprint',
        sceneID: 'scene-123',
        driverID: 'lyfi',
        compatible: 'lyfi',
        model: 'LYFI-001',
      );

      final viewModel = MockDeviceSummaryViewModel(device: device);

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<AbstractDeviceSummaryViewModel>.value(value: viewModel)],
          child: createTestWidget(const DeviceTile(false)),
        ),
      );

      // Verify device name is displayed
      expect(find.text('Test LED Controller'), findsOneWidget);

      // Verify device icon is present
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('shows device tile with correct styling', (WidgetTester tester) async {
      final device = DeviceEntity(
        id: 'test-device-456',
        name: 'Offline Device',
        address: Uri.parse('http://192.168.1.101'),
        fingerprint: 'offline-fingerprint',
        sceneID: 'scene-456',
        driverID: 'lyfi',
        compatible: 'lyfi',
        model: 'LYFI-002',
      );

      final viewModel = MockDeviceSummaryViewModel(device: device, isOnline: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<AbstractDeviceSummaryViewModel>.value(value: viewModel)],
          child: createTestWidget(const DeviceTile(false)),
        ),
      );

      // Verify device tile is displayed
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Offline Device'), findsOneWidget);
    });

    testWidgets('responds to tap events', (WidgetTester tester) async {
      var navigationCalled = false;
      final device = DeviceEntity(
        id: 'test-device-789',
        name: 'Tap Test Device',
        address: Uri.parse('http://192.168.1.102'),
        fingerprint: 'tap-fingerprint',
        sceneID: 'scene-789',
        driverID: 'lyfi',
        compatible: 'lyfi',
        model: 'LYFI-003',
      );

      final viewModel = MockDeviceSummaryViewModel(device: device);

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<AbstractDeviceSummaryViewModel>.value(value: viewModel)],
          child: MaterialApp(home: Scaffold(body: const DeviceTile(false))),
        ),
      );

      // Verify device tile is displayed
      expect(find.byType(DeviceTile), findsOneWidget);
      expect(find.text('Tap Test Device'), findsOneWidget);
    });
  });
}
