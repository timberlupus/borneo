# Borneo Client - AI Coding Guidelines

## Overview

Borneo Client is a cross-platform Flutter application for controlling Borneo-IoT devices, providing real-time control, scheduling, and device management.

## Technology Stack

- **Framework**: Flutter
- **Language**: Dart
- **Platforms**: iOS, Android, Linux, Desktop
- **State Management**: Provider
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

### Localization

- To manage translation assets, use the helper script under `scripts/bopo.py`.
  - `python .\scripts\bopo.py update <project_path>` – generate/update the
    `messages.pot` and all `.po` files based on Dart source strings.
  - `python .\scripts\bopo.py missing <project_path>` – list any
    untranslated entries (`msgstr` empty) across `.po` files along with path and line
    number. This is useful for spotting work still to be done.
- After running the update command, translate or review the `.po` files as needed.
- During development tasks, do not modify `.po` files temporarily; translate them uniformly before release.

Use the following patterns for localizing user-visible text with `flutter_gettext`:

- Import: `import 'package:gettext_i18n/gettext_i18n.dart';`
- Positional arguments: `Text(context.translate('There is {0} apple', keyPlural: 'There are {0} apples', pArgs: [1]));`
- Named arguments: `Text(context.translate('You have {message_count} message', keyPlural: 'You have {message_count} messages', nArgs: {'message_count': 1}));`

## Contributing

- Follow Flutter conventions
- Add tests for new features
- Update localization files for UI changes