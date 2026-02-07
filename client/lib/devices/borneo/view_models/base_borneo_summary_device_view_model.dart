import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:lw_wot/wot.dart';

abstract class BaseBorneoSummaryDeviceViewModel extends AbstractDeviceSummaryViewModel {
  WotThing? wotThing;

  BaseBorneoSummaryDeviceViewModel(super.deviceEntity, super.deviceManager, super.globalEventBus) {
    wotThing = deviceManager.getWotThing(deviceEntity.id);
  }
}
