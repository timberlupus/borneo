import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/device.dart';

abstract class ILyfiDeviceApi extends IBorneoDeviceApi {
  LyfiDeviceInfo getLyfiInfo(Device dev);
  Future<LyfiDeviceStatus> getLyfiStatus(Device dev);

  Future<LyfiState> getState(Device dev);
  Future<void> switchState(Device dev, LyfiState state);

  Future<LyfiMode> getMode(Device dev);
  Future<void> switchMode(Device dev, LyfiMode mode);

  Future<List<ScheduledInstant>> getSchedule(Device dev);
  Future<void> setSchedule(Device dev, Iterable<ScheduledInstant> schedule);

  Future<List<int>> getColor(Device dev);
  Future<void> setColor(Device dev, List<int> color);

  Future<int> getKeepTemp(Device dev);

  Future<LedCorrectionMethod> getCorrectionMethod(Device dev);
  Future<void> setCorrectionMethod(Device dev, LedCorrectionMethod mode);

  Future<Duration> getTemporaryDuration(Device dev);
  Future<void> setTemporaryDuration(Device dev, Duration duration);

  Future<GeoLocation?> getLocation(Device dev);
  Future<void> setLocation(Device dev, GeoLocation location);

  Future<bool> getTimeZoneEnabled(Device dev);
  Future<void> setTimeZoneEnabled(Device dev, bool enabled);

  Future<int> getTimeZoneOffset(Device dev);
  Future<void> setTimeZoneOffset(Device dev, int offset);

  Future<AcclimationSettings> getAcclimation(Device dev);
  Future<void> setAcclimation(Device dev, AcclimationSettings acc);
  Future<void> terminateAcclimation(Device dev);

  Future<List<ScheduledInstant>> getSunSchedule(Device dev);
  Future<List<SunCurveItem>> getSunCurve(Device dev);
}
