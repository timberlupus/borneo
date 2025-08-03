# Integration Tests for Borneo App

This directory contains integration tests for the Borneo Flutter application. These tests verify the complete app functionality from user interaction to data persistence.

## Test Structure

- `app_test.dart`: Basic app startup and navigation tests
- `device_management_test.dart`: Device discovery, grouping, and management tests
- `scene_management_test.dart`: Scene creation, editing, and deletion tests
- `routines_test.dart`: Routine management and execution tests

## Running the Tests

### Prerequisites
1. Ensure you have a device or emulator running
2. Install dependencies: `flutter pub get`

### Commands

#### Run all integration tests:
```bash
flutter test integration_test/
```

#### Run specific test file:
```bash
flutter test integration_test/app_test.dart
flutter test integration_test/device_management_test.dart
flutter test integration_test/scene_management_test.dart
flutter test integration_test/routines_test.dart
```

#### Run on specific device:
```bash
flutter test integration_test/ -d <device_id>
```

#### Run with debugging:
```bash
flutter run integration_test/app_test.dart
```

## Test Features Covered

### App Core
- App startup and initialization
- Navigation between main tabs
- Basic UI responsiveness

### Device Management
- Device discovery flow
- Device grouping functionality
- Device details navigation
- Refresh functionality

### Scene Management
- Scene list loading
- Scene creation flow
- Scene editing
- Scene deletion
- Scene details navigation

### Routines
- Routine list loading
- Routine activation/deactivation
- Manual routine execution
- Routine details navigation

## Writing New Tests

When adding new integration tests:

1. Create a new test file in the `integration_test/` directory
2. Follow the existing naming convention: `feature_test.dart`
3. Use `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` at the start
4. Group related tests using `group()`
5. Use descriptive test names that explain what is being tested
6. Include appropriate wait times for async operations
7. Handle both success and empty states gracefully

## Best Practices

- Use `pumpAndSettle()` with reasonable timeouts for async operations
- Always check for both empty states and populated states
- Use `findsOneWidget`, `findsNothing`, and `findsWidgets` appropriately
- Include error handling for when expected UI elements might not be present
- Test both happy paths and edge cases
- Keep tests independent - each test should set up its own state

## Troubleshooting

### Common Issues

1. **Tests failing due to animations**: Add longer pump durations
2. **Network timeouts**: Ensure test devices have internet access
3. **Permission dialogs**: Handle permission requests in setup
4. **State persistence**: Consider clearing app data between test runs

### Debugging Tips

- Use `flutter run` instead of `flutter test` to see the app during test execution
- Add `debugDumpApp()` to inspect widget tree during test failure
- Use `print()` statements for debugging test flow
- Take screenshots on test failure using `binding.takeScreenshot()`