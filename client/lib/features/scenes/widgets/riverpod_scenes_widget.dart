import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

// Your existing services
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/routine_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

// Your Riverpod providers
import 'package:borneo_app/features/scenes/providers/scenes_provider.dart';
import 'package:borneo_app/features/routines/providers/routines_provider.dart';
import 'package:borneo_app/features/scenes/views/scenes_screen_riverpod.dart';

/// Bridge widget that integrates Riverpod scenes with existing Provider context
///
/// This widget automatically reads all necessary services from the existing Provider
/// context and provides them to the Riverpod ProviderScope. This allows seamless
/// integration of Riverpod-based scenes functionality in the existing Provider-based app.
///
/// Usage:
/// ```dart
/// // In your existing Provider-based app:
/// TabBarView(
///   children: [
///     RiverpodScenesWidget(), // Uses Riverpod internally
///     DevicesTab(),           // Keep existing Provider-based widgets
///     MyTab(),
///   ],
/// )
/// ```
class RiverpodScenesWidget extends StatelessWidget {
  const RiverpodScenesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Read services from the existing Provider context
    final sceneManager = provider.Provider.of<ISceneManager>(context, listen: false);
    final deviceManager = provider.Provider.of<IDeviceManager>(context, listen: false);
    final routineManager = provider.Provider.of<IRoutineManager>(context, listen: false);
    final notificationService = provider.Provider.of<IAppNotificationService>(context, listen: false);
    final eventBus = provider.Provider.of<EventBus>(context, listen: false);
    final logger = provider.Provider.of<Logger?>(context, listen: false);
    return ProviderScope(
      overrides: [
        // Override Riverpod providers with actual instances from Provider context
        sceneManagerProvider.overrideWithValue(sceneManager),
        deviceManagerProvider.overrideWithValue(deviceManager),
        routineManagerProvider.overrideWithValue(routineManager),
        appNotificationServiceProvider.overrideWithValue(notificationService),
        eventBusProvider.overrideWithValue(eventBus),
        loggerProvider.overrideWithValue(logger),
      ],
      child: const ScenesScreenRiverpod(),
    );
  }
}
