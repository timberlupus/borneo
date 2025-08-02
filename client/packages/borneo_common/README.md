## Borneo Common

This package provides common utilities and abstractions for the Borneo project.

### Features

- Async rate limiter
- DateTime and Duration extensions
- Custom exceptions
- Network interface helpers
- RSSI level utilities
- Disposable resource pattern
- Float32 utilities
- Simple state machine

### Usage

Add to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  borneo_common:
    path: packages/borneo_common
```

Import what you need:

```dart
import 'package:borneo_common/borneo_common.dart';
```

Or import specific utilities:

```dart
import 'package:borneo_common/utils/disposable.dart';
```

### License

See [LICENSE](LICENSE).
