import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class MonitoringInterceptor extends Interceptor {
  final _starts = <int, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _starts[options.hashCode] = DateTime.now();
    Sentry.addBreadcrumb(Breadcrumb.http(
      url: options.uri,
      method: options.method,
      level: SentryLevel.info,
    ));
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final start = _starts.remove(response.requestOptions.hashCode);
    final ms = start == null ? 0 : DateTime.now().difference(start).inMilliseconds;
    if (ms > 2000) {
      Sentry.captureMessage(
        'slow_api ${response.requestOptions.method} ${response.requestOptions.uri} ${ms}ms',
        level: SentryLevel.warning,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Sentry.captureException(err, stackTrace: err.stackTrace);
    handler.next(err);
  }
}
