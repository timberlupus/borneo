# Borneo Kernel Abstractions

This package provides core abstractions and interfaces for the Borneo project kernel.

## Features

- Device and driver interfaces
- Device event bus
- Command queue
- Error types for device operations
- mDNS discovery abstractions
- Bound device and driver data models

## Usage

Add to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  borneo_kernel_abstractions:
    path: packages/borneo_kernel_abstractions
```

Import what you need:

```dart
import 'package:borneo_kernel_abstractions/kernel.dart';
```

Or import specific interfaces or models:

```dart
import 'package:borneo_kernel_abstractions/ikernel.dart';
```

## License

See [LICENSE](LICENSE).
