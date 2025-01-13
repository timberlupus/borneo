import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/foundation.dart';

abstract class IEditor extends ChangeNotifier {
  bool get canEdit;
  bool get isChanged;
  Future<void> save();
  Future<void> initialize();
  Future<void> updateChannelValue(int index, int value);
  int get availableChannelCount;
  LyfiDeviceInfo get deviceInfo;
  List<ValueNotifier<int>> get channels;
}
