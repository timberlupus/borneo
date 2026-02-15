import 'package:borneo_app/features/chores/models/abstract_chore.dart';
import 'package:borneo_common/borneo_common.dart';

abstract class IChoreManager implements IDisposable {
  List<AbstractChore> getAvailableChores();
  Future<void> executeChore(String choreId);
  Future<void> undoChore(String choreId);
  Future<bool> hasHistoryForChore(String choreId);
}
