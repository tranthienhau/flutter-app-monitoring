import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/monitoring/monitoring_client.dart';
import 'features/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final monitoring = MonitoringClient();
  await monitoring.init();

  runZonedGuarded(
    () => SentryWidget(
      child: ProviderScope(
        overrides: [
          monitoringClientProvider.overrideWithValue(monitoring),
        ],
        child: const MonitoringApp(),
      ),
    ).let(runApp),
    (e, s) => monitoring.captureException(e, stackTrace: s),
  );
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class MonitoringApp extends StatelessWidget {
  const MonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Monitoring',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}
