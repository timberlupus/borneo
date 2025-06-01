import 'package:sembast/sembast.dart';

class RoutineHistoryRecord {
  final String routineId;
  final DateTime timestamp;
  final List<Map<String, dynamic>> steps;

  RoutineHistoryRecord({required this.routineId, required this.timestamp, required this.steps});

  Map<String, dynamic> toJson() => {'routineId': routineId, 'timestamp': timestamp.toIso8601String(), 'steps': steps};

  static RoutineHistoryRecord fromJson(Map<String, dynamic> json) => RoutineHistoryRecord(
    routineId: json['routineId'],
    timestamp: DateTime.parse(json['timestamp']),
    steps: List<Map<String, dynamic>>.from(json['steps'] ?? []),
  );
}

class RoutineHistoryStore {
  final StoreRef<int, Map<String, dynamic>> _store = intMapStoreFactory.store('routine_history');
  final Database db;

  RoutineHistoryStore(this.db);

  Future<void> addRecord(RoutineHistoryRecord record) async {
    await _store.add(db, record.toJson());
  }

  Future<List<RoutineHistoryRecord>> getAllRecords() async {
    final snapshots = await _store.find(db);
    return snapshots.map((snap) => RoutineHistoryRecord.fromJson(snap.value)).toList();
  }

  Future<void> clear() async {
    await _store.delete(db);
  }
}
