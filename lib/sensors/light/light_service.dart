import 'package:light/light.dart';

import '../../core/util/low_pass.dart';

/// Ambient light in lux, smoothed so the background does not flicker (e.g. when
/// passing under a bridge). Android only; on a device without the sensor the
/// stream simply never emits and the default ambient stays. The service only
/// produces data — the mood decision stays in `MoodResolver`.
class LightService {
  LightService({required this.source, this.smoothing = 0.1});

  /// Raw lux samples.
  final Stream<double> source;
  final double smoothing;

  factory LightService.fromPlugin({double smoothing = 0.1}) => LightService(
        source: Light().lightSensorStream.map((lux) => lux.toDouble()),
        smoothing: smoothing,
      );

  Stream<double> lux() {
    final lp = LowPass(factor: smoothing, initial: 12000);
    return source.map(lp.add);
  }
}
