import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/monitoring/monitoring_client.dart';
import '../../core/monitoring/uptime_prober.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoring = ref.watch(monitoringClientProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Health Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Uptime probes', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<ProbeResult>(
                stream: monitoring.uptime.results$,
                builder: (context, _) {
                  final results = monitoring.uptime.latest.values.toList();
                  if (results.isEmpty) {
                    return const Center(child: Text('Waiting for first probe...'));
                  }
                  return ListView(
                    children: [
                      for (final r in results)
                        ListTile(
                          leading: Icon(
                            r.ok ? Icons.check_circle : Icons.error,
                            color: r.ok ? Colors.green : Colors.red,
                          ),
                          title: Text(r.url),
                          subtitle: Text('${r.latencyMs}ms${r.error == null ? '' : ' - ${r.error}'}'),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Slow frames: ${monitoring.performance.slowFrameCount}'),
                Text('Total frames: ${monitoring.performance.totalFrameCount}'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => monitoring.captureException(
                Exception('Test crash from dashboard'),
                stackTrace: StackTrace.current,
              ),
              child: const Text('Trigger test crash'),
            ),
          ],
        ),
      ),
    );
  }
}
