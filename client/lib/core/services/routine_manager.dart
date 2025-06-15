import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/features/routines/models/abstract_routine.dart';
import 'package:borneo_app/features/routines/models/builtin_routines.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:borneo_app/core/services/routine_history_store.dart';
import 'package:borneo_common/borneo_common.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:synchronized/synchronized.dart';

class RoutineManager implements IDisposable {
  final Logger? logger;

  // ignore: unused_field
  final Database _db;

  final _routineOpLock = Lock();

  // ignore: unused_field
  final EventBus _globalBus;

  final SceneManager _sceneManager;
  final DeviceManager _deviceManager;

  final RoutineHistoryStore _historyStore;

  final List<AbstractRoutine> allRoutines = [];

  RoutineManager(this._globalBus, this._db, this._sceneManager, this._deviceManager, {this.logger})
    : _historyStore = RoutineHistoryStore(_db) {
    allRoutines.addAll([PowerOffAllRoutine(), FeedModeRoutine(), WaterChangeModeRoutine(), DryScapeModeRoutine()]);
  }

  List<AbstractRoutine> getAvailableRoutines() {
    List<AbstractRoutine> routines = [];
    final currentScene = _sceneManager.current;
    for (final r in allRoutines) {
      if (r.checkAvailable(currentScene, _deviceManager)) {
        routines.add(r);
      }
    }
    return routines;
  }

  Future<void> executeRoutine(String routineID) async {
    await _routineOpLock.synchronized(() async {
      final routine = allRoutines.singleWhere((r) => r.id == routineID);
      final currentScene = _sceneManager.current;
      final steps = await routine.execute(currentScene, _deviceManager);
      if (steps.isNotEmpty) {
        await _historyStore.addRecord(
          RoutineHistoryRecord(routineId: routineID, timestamp: DateTime.now(), steps: steps),
        );
      }
    });
  }

  Future<void> undoRoutine(String routineID) async {
    await _routineOpLock.synchronized(() async {
      final routine = allRoutines.singleWhere((r) => r.id == routineID);
      final records = await _historyStore.getAllRecords();
      final last = records.where((r) => r.routineId == routineID).lastOrNull;
      if (last == null) return;
      final stepObjs = last.steps.map(routine.createAction).toList();
      for (final step in stepObjs.reversed) {
        await step.undo(_deviceManager);
      }
      await _historyStore.clearByRoutineId(routineID);
    });
  }

  @override
  void dispose() {
    // do nothing
  }
}
