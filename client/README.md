# Borneo Mobile Application

This directory contains the Flutter mobile client for the Borneo project.

## Overview

The Borneo Mobile Application is a cross-platform app built with Flutter, designed to provide a modern and responsive user experience for the Borneo IoT ecosystem. It integrates with Borneo's backend services and supports both Android and iOS platforms.

## Project Structure

- `lib/` — Main application source code (features, core, shared, etc.)
- `assets/` — Static resources (images, translations, data)
- `test/` — Unit and widget tests
- `android/`, `ios/`, `linux/`, `macos/`, `windows/` — Platform-specific code
- `packages/` — Shared Dart/Flutter packages for the Borneo project

## Getting Started

1. Install Flutter (see [Flutter docs](https://docs.flutter.dev/get-started/install))
2. Run `flutter pub get` to fetch dependencies
3. (Optional) Generate code and assets:

   ```bash
   flutter packages pub run build_runner build
   dart run flutter_native_splash:create
   ```

4. Run the app:

   ```bash
   flutter run
   ```

## Development

- Use `melos` for managing multiple packages if working across the monorepo
- Code style and analysis are enforced via `analysis_options.yaml`
- Localization files are in `assets/i18n/`
- Main entry points: `lib/main.dart`

## Testing

Run all tests:

```bash
flutter test
```

## Useful Commands

- Build runner: `flutter packages pub run build_runner build`
- Generate splash: `dart run flutter_native_splash:create`
- Generate Icons: `flutter pub add flutter_launcher_icons`
- Analyze code: `flutter analyze --no-pub`
- Format code: `flutter format .`

## Credits

- posix_tz_db: <https://github.com/nayarsystems/posix_tz_db/blob/master/zones.json>
