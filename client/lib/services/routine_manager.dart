import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/models/routines/builtin_routines.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/routine_history_store.dart';
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

  final RoutineHistoryStore _historyStore;

  final List<AbstractRoutine> allRoutines = [];

  RoutineManager(this._globalBus, this._db, this._deviceManager, {this.logger})
    : _historyStore = RoutineHistoryStore(_db) {
    allRoutines.addAll([PowerOffAllRoutine(), FeedModeRoutine(), WaterChangeModeRoutine(), DryScapeModeRoutine()]);
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
    final routine = allRoutines.singleWhere((r) => r.id == routineID);
    if (routine is PersistentRoutineMixin) {
      await routine.executeAndPersist(_deviceManager, _historyStore, routineID);
    } else {
      await routine.execute(_deviceManager);
    }
  }

  Future<void> undoRoutine(String routineID) async {
    final routine = allRoutines.singleWhere((r) => r.id == routineID);
    if (routine is PersistentRoutineMixin) {
      await routine.undoFromHistory(_deviceManager, _historyStore, routineID);
    } else {
      await routine.undo(_deviceManager);
    }
  }

  @override
  void dispose() {
    // do nothing
  }
}
