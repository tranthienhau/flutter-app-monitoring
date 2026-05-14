import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ProbeResult {
  ProbeResult({required this.url, required this.ok, required this.latencyMs, this.error});
  final String url;
  final bool ok;
  final int latencyMs;
  final Object? error;
}

class UptimeProber {
  UptimeProber({
    required this.urls,
    this.interval = const Duration(seconds: 60),
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

  final List<String> urls;
  final Duration interval;
  final Dio _dio;
  Timer? _timer;
  final _resultController = StreamController<ProbeResult>.broadcast();
  final Map<String, ProbeResult> _latest = {};

  Stream<ProbeResult> get results$ => _resultController.stream;
  Map<String, ProbeResult> get latest => Map.unmodifiable(_latest);

  void start() {
    _timer?.cancel();
    _probeOnce();
    _timer = Timer.periodic(interval, (_) => _probeOnce());
  }

  void stop() {
    _timer?.cancel();
    _resultController.close();
  }

  Future<void> _probeOnce() async {
    for (final url in urls) {
      final sw = Stopwatch()..start();
      try {
        final res = await _dio.head(url);
        final ok = res.statusCode != null && res.statusCode! < 500;
        final r = ProbeResult(url: url, ok: ok, latencyMs: sw.elapsedMilliseconds);
        _emit(r);
        if (!ok) {
          await Sentry.captureMessage(
            'uptime_degraded: $url status=${res.statusCode}',
            level: SentryLevel.warning,
          );
        }
      } catch (e) {
        final r = ProbeResult(url: url, ok: false, latencyMs: sw.elapsedMilliseconds, error: e);
        _emit(r);
        await Sentry.captureMessage(
          'uptime_down: $url',
          level: SentryLevel.error,
        );
      }
    }
  }

  void _emit(ProbeResult r) {
    _latest[r.url] = r;
    _resultController.add(r);
  }
}
