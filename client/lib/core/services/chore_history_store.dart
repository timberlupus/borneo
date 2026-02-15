import 'package:sembast/sembast.dart';

class ChoreHistoryRecord {
  final String choreId;
  final DateTime timestamp;
  final List<Map<String, dynamic>> steps;

  ChoreHistoryRecord({required this.choreId, required this.timestamp, required this.steps});

  Map<String, dynamic> toJson() => {'choreId': choreId, 'timestamp': timestamp.toIso8601String(), 'steps': steps};

  static ChoreHistoryRecord fromJson(Map<String, dynamic> json) => ChoreHistoryRecord(
    choreId: json['choreId'],
    timestamp: DateTime.parse(json['timestamp']),
    steps: List<Map<String, dynamic>>.from(json['steps'] ?? []),
  );
}

class ChoreHistoryStore {
  final StoreRef<int, Map<String, dynamic>> _store = intMapStoreFactory.store('chore_history');
  final Database db;

  ChoreHistoryStore(this.db);

  Future<void> addRecord(ChoreHistoryRecord record) async {
    await _store.add(db, record.toJson());
  }

  Future<List<ChoreHistoryRecord>> getAllRecords() async {
    final snapshots = await _store.find(db);
    return snapshots.map((snap) => ChoreHistoryRecord.fromJson(snap.value)).toList();
  }

  Future<void> clear() async {
    await _store.delete(db);
  }

  Future<void> clearByChoreId(String choreId) async {
    final snapshots = await _store.find(db);
    for (final snap in snapshots) {
      final value = snap.value;
      if (value['choreId'] == choreId) {
        await _store.record(snap.key).delete(db);
      }
    }
  }

  Future<bool> hasHistoryForChore(String choreId) async {
    final snapshots = await _store.find(db, finder: Finder(filter: Filter.equals('choreId', choreId)));
    return snapshots.isNotEmpty;
  }
}
