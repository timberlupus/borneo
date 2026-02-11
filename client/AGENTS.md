# Borneo Client - AI Coding Guidelines

## Overview

Borneo Client is a cross-platform Flutter application for controlling Borneo-IoT devices, providing real-time control, scheduling, and device management.

## Technology Stack

- **Framework**: Flutter
- **Language**: Dart
- **Platforms**: iOS, Android, Web, Desktop
- **State Management**: Provider/Bloc (check code)
- **Networking**: CoAP with CBOR

## Project Structure

- `lib/`: Main source code
  - `main.dart`: App entry point
  - `app/`: Application logic
  - `core/`: Core utilities
  - `devices/`: Device models
  - `features/`: Feature modules
  - `routes/`: Navigation
  - `shared/`: Shared components
- `assets/`: Images, translations, data
- `packages/`: Shared packages (borneo_common, etc.)
- `test/`: Unit and integration tests

## Development Guidelines

### Coding Standards

- Follow Dart style guide
- Use `analysis_options.yaml` for linting
- Format code with `dart format .` after each code modification
- Implement with Flutter best practices
- Use Provider for state management

### Building and Running

- Install Flutter SDK
- Run `flutter pub get`
- Generate assets: `flutter packages pub run build_runner build`
- Analyze code: `flutter analyze`
- Run app: `flutter run`
- Test: `flutter test`

### Key Features

- Device discovery and control
- Scheduling and automation
- OTA updates
- Localization support

### Testing

- Unit tests in `test/`
- Integration tests in `integration_test/`
- Use `flutter test` to run

## Contributing

- Follow Flutter conventions
- Add tests for new features
- Update localization files for UI changes