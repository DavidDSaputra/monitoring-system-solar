import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_base_urls.dart';

class MonitoringHealthService {
  final List<String> _baseUrls;
  final http.Client _httpClient;

  MonitoringHealthService({String? baseUrl, http.Client? httpClient})
    : _baseUrls = resolveMonitoringApiBaseUrls(overrideBaseUrl: baseUrl),
      _httpClient = httpClient ?? http.Client();

  Future<MonitoringHealth> getHealth() async {
    Object? lastError;

    for (final baseUrl in prioritizeMonitoringBaseUrls(_baseUrls)) {
      try {
        final uri = Uri.parse('$baseUrl/health.php');
        final response = await _httpClient
            .get(uri)
            .timeout(
              monitoringApiTimeoutFor(
                baseUrl,
                fallback: const Duration(seconds: 3),
              ),
            );
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const MonitoringHealthException('Invalid health response');
        }
        if (response.statusCode != 200 || decoded['success'] != true) {
          throw MonitoringHealthException(
            decoded['message']?.toString() ?? 'Backend health unavailable',
          );
        }

        rememberMonitoringBaseUrl(baseUrl);
        return MonitoringHealth.fromJson(decoded, baseUrl);
      } catch (e) {
        lastError = e;
      }
    }

    throw MonitoringHealthException(
      'Backend tidak bisa dihubungi. Debug HP: jalankan adb reverse tcp:8080 tcp:80. Detail: $lastError',
    );
  }

  void dispose() => _httpClient.close();
}

class MonitoringHealth {
  final String status;
  final String baseUrl;
  final DateTime? serverTime;
  final Map<String, ProviderHealth> providers;

  const MonitoringHealth({
    required this.status,
    required this.baseUrl,
    required this.serverTime,
    required this.providers,
  });

  bool get isOk => status == 'ok';

  factory MonitoringHealth.fromJson(Map<String, dynamic> json, String baseUrl) {
    final rawProviders = json['providers'];
    final providers = <String, ProviderHealth>{};
    if (rawProviders is Map) {
      for (final entry in rawProviders.entries) {
        final value = entry.value;
        if (value is Map) {
          providers[entry.key.toString()] = ProviderHealth.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    return MonitoringHealth(
      status: json['status']?.toString() ?? 'unknown',
      baseUrl: baseUrl,
      serverTime: DateTime.tryParse(json['serverTime']?.toString() ?? ''),
      providers: providers,
    );
  }
}

class ProviderHealth {
  final String source;
  final bool configured;
  final String status;

  const ProviderHealth({
    required this.source,
    required this.configured,
    required this.status,
  });

  bool get isUsable => status == 'ok' || status == 'stale';

  factory ProviderHealth.fromJson(Map<String, dynamic> json) {
    return ProviderHealth(
      source: json['source']?.toString() ?? '',
      configured: json['configured'] == true,
      status: json['status']?.toString() ?? 'unknown',
    );
  }
}

class MonitoringHealthException implements Exception {
  final String message;

  const MonitoringHealthException(this.message);

  @override
  String toString() => message;
}
