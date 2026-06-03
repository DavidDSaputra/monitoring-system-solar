import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_constants.dart';

String? _lastHealthyMonitoringBaseUrl;

List<String> resolveMonitoringApiBaseUrls({String? overrideBaseUrl}) {
  final configured = overrideBaseUrl ?? dotenv.env['MONITORING_API_BASE_URLS'];
  final rawUrls = configured?.trim().isNotEmpty == true
      ? configured!.split(',')
      : [
          dotenv.env['MONITORING_API_BASE_URL'] ??
              AppConstants.defaultMonitoringApiBaseUrl,
        ];

  final urls = rawUrls
      .map((url) => url.trim().replaceFirst(RegExp(r'/+$'), ''))
      .where((url) => url.isNotEmpty)
      .toList();

  if (urls.isEmpty) return [AppConstants.defaultMonitoringApiBaseUrl];
  final mobileLocalFirst =
      dotenv.env['MONITORING_API_MOBILE_LOCAL_FIRST']?.toLowerCase() == 'true';

  final local = <String>[];
  final nonLocal = <String>[];
  for (final url in urls) {
    (_isLocalApiUrl(url) ? local : nonLocal).add(url);
  }

  final browserHost = Uri.base.host;
  if (kIsWeb && browserHost.isNotEmpty && !_isLocalHost(browserHost)) {
    final sameHost = urls.where((url) => _hostOf(url) == browserHost).toList();
    final derived = '${Uri.base.scheme}://$browserHost/jarwinn-monitoring/api';
    return _unique([...sameHost, derived, ...nonLocal, ...local]);
  }

  if (!kIsWeb) {
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (mobile) {
      return mobileLocalFirst
          ? _unique([...local, ...nonLocal])
          : _unique([...nonLocal, ...local]);
    }
  }

  return _unique([...local, ...nonLocal]);
}

List<String> prioritizeMonitoringBaseUrls(List<String> urls) {
  final healthy = _lastHealthyMonitoringBaseUrl;
  if (healthy == null || !urls.contains(healthy)) return urls;
  return _unique([healthy, ...urls]);
}

void rememberMonitoringBaseUrl(String url) {
  _lastHealthyMonitoringBaseUrl = url.trim().replaceFirst(RegExp(r'/+$'), '');
}

Duration monitoringApiTimeoutFor(
  String baseUrl, {
  Duration fallback = const Duration(seconds: 5),
}) {
  if (_isLocalApiUrl(baseUrl)) return const Duration(seconds: 2);
  return fallback;
}

List<String> _unique(List<String> urls) {
  final seen = <String>{};
  return [
    for (final url in urls)
      if (seen.add(url)) url,
  ];
}

bool _isLocalApiUrl(String url) {
  if (!url.contains('://')) return true;
  final host = _hostOf(url);
  return host == null || _isLocalHost(host);
}

bool _isLocalHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

String? _hostOf(String url) {
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return null;
  }
}
