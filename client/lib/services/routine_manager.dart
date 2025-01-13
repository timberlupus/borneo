import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/models/routines/builtin_routines.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_common/borneo_common.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';

class RoutineManager implements IDisposable {
  final Logger? logger;

  // ignore: unused_field
  final Database _db;

  // ignore: unused_field
  final EventBus _globalBus;

  final DeviceManager _deviceManager;

  final List<AbstractRoutine> allRoutines = [];

  RoutineManager(
    this._globalBus,
    this._db,
    this._deviceManager, {
    this.logger,
  }) {
    allRoutines.addAll([
      PowerOffAllRoutine(),
      FeedModeRoutine(),
      WaterChangeModeRoutine(),
      DryScapeModeRoutine(),
    ]);
  }

  List<AbstractRoutine> getAvailableRoutines() {
    List<AbstractRoutine> routines = [];
    for (final r in allRoutines) {
      if (r.checkAvailable(_deviceManager)) {
        routines.add(r);
      }
    }
    return routines;
  }

  Future<void> executeRoutine(String routineID) async {
    await allRoutines
        .singleWhere((r) => r.id == routineID)
        .execute(_deviceManager);
  }

  @override
  void dispose() {
    // do nothing
  }
}
