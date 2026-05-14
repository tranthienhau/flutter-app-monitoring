import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'performance_observer.dart';
import 'uptime_prober.dart';

final monitoringClientProvider = Provider<MonitoringClient>(
  (_) => throw UnimplementedError(),
);

class MonitoringClient {
  late final PerformanceObserver performance;
  late final UptimeProber uptime;

  Future<void> init({String? sentryDsn, List<String> uptimeUrls = const []}) async {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    PlatformDispatcher.instance.onError = (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s, fatal: true);
      return true;
    };

    await SentryFlutter.init((o) {
      o.dsn = sentryDsn ?? const String.fromEnvironment('SENTRY_DSN');
      o.tracesSampleRate = 0.2;
      o.profilesSampleRate = 0.2;
      o.attachScreenshot = true;
      o.attachViewHierarchy = true;
    });

    performance = PerformanceObserver()..start();
    uptime = UptimeProber(urls: uptimeUrls)..start();
  }

  Future<void> captureException(Object e, {StackTrace? stackTrace}) async {
    await Sentry.captureException(e, stackTrace: stackTrace);
    await FirebaseCrashlytics.instance.recordError(e, stackTrace);
  }

  void track(String event, {Map<String, Object?> props = const {}}) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: event,
      data: props,
      category: 'app.event',
    ));
  }

  void dispose() {
    performance.stop();
    uptime.stop();
  }
}
