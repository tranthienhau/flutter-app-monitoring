import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_app_monitoring/core/monitoring/monitoring_client.dart';
import 'package:flutter_app_monitoring/core/monitoring/performance_observer.dart';
import 'package:flutter_app_monitoring/core/monitoring/uptime_prober.dart';
import 'package:flutter_app_monitoring/features/dashboard/dashboard_screen.dart';

/// A Dio HttpClientAdapter that returns canned 200/slow responses, so the
/// UptimeProber populates real ProbeResults without touching the network or
/// Sentry. Drives the live StreamBuilder in DashboardScreen with real data.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusByPath);

  /// Maps a path substring to the HTTP status it should return.
  final Map<String, int> statusByPath;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var status = 200;
    for (final entry in statusByPath.entries) {
      if (options.uri.toString().contains(entry.key)) {
        status = entry.value;
        break;
      }
    }
    return ResponseBody.fromString('', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

/// Test double for MonitoringClient: skips Firebase + Sentry init and seeds
/// the uptime prober with realistic endpoints so the dashboard renders a real,
/// populated health view.
class _SeededMonitoringClient extends MonitoringClient {
  @override
  Future<void> init({String? sentryDsn, List<String> uptimeUrls = const []}) async {
    performance = PerformanceObserver();
    // payments endpoint reports a 503 so the dashboard shows a real DOWN row.
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter({'payments': 503});
    uptime = UptimeProber(
      urls: const [
        'https://api.acme.io/healthz',
        'https://auth.acme.io/healthz',
        'https://payments.acme.io/healthz',
        'https://cdn.acme.io/status',
      ],
      dio: dio,
    );
    // Prime the prober once so `latest` is populated for the first frame.
    uptime.start();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot(name);
  }

  testWidgets('capture monitoring dashboard flow', (tester) async {
    final monitoring = _SeededMonitoringClient();
    await monitoring.init();
    // Let the seeded probes resolve.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monitoringClientProvider.overrideWithValue(monitoring),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    // Full health dashboard: live uptime probes + frame counters + crash action.
    await shoot(tester, '01-health-dashboard');

    // The payments endpoint is degraded (503) - verify the dashboard shows
    // both healthy and DOWN rows, then capture the uptime detail view.
    expect(find.text('https://payments.acme.io/healthz'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsWidgets);
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, '02-uptime-probes');

    // Capture the crash-reporting action row (Sentry + Crashlytics hook).
    final crashBtn = find.text('Trigger test crash');
    expect(crashBtn, findsOneWidget);
    await tester.ensureVisible(crashBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, '03-crash-reporting');
  });
}
