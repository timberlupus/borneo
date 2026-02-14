import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/foundation.dart';

abstract class IEditor extends ChangeNotifier {
  bool get canEdit;
  bool get isChanged;
  Future<void> save({CancellationToken? cancelToken});
  Future<void> initialize({CancellationToken? cancelToken});
  Future<void> updateChannelValue(int index, int value);
  int get availableChannelCount;
  LyfiDeviceInfo get deviceInfo;
  List<ValueNotifier<int>> get channels;
}
