import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class PerformanceObserver {
  StreamController<int>? _slowFrameController;
  int _slowFrames = 0;
  int _totalFrames = 0;

  Stream<int> get slowFrames$ =>
      (_slowFrameController ??= StreamController.broadcast()).stream;
  int get slowFrameCount => _slowFrames;
  int get totalFrameCount => _totalFrames;

  void start() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _slowFrameController?.close();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _totalFrames++;
      final totalMs = t.totalSpan.inMilliseconds;
      if (totalMs > 32) {
        _slowFrames++;
        _slowFrameController?.add(totalMs);
        Sentry.metrics().distribution(
          'frame.total_ms',
          value: totalMs.toDouble(),
          unit: const DurationSentryMeasurementUnit(DurationUnit.milliSecond),
        );
      }
    }
  }
}
