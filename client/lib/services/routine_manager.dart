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
    final steps = await routine.execute(_deviceManager);
    if (steps.isNotEmpty) {
      await _historyStore.addRecord(
        RoutineHistoryRecord(routineId: routineID, timestamp: DateTime.now(), steps: steps),
      );
    }
  }

  Future<void> undoRoutine(String routineID) async {
    final routine = allRoutines.singleWhere((r) => r.id == routineID);
    final records = await _historyStore.getAllRecords();
    final last = records.where((r) => r.routineId == routineID).lastOrNull;
    if (last == null) return;
    final stepObjs = last.steps.map(routine.createAction).toList();
    for (final step in stepObjs.reversed) {
      await step.undo(_deviceManager);
    }
    // 清除该 routine 的所有历史记录
    await _historyStore.clearByRoutineId(routineID);
  }

  @override
  void dispose() {
    // do nothing
  }
}
