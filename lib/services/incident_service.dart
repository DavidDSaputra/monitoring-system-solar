import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_base_urls.dart';
import '../models/incident.dart';
import 'offline_cache_service.dart';

class IncidentResult {
  final List<Incident> records;
  final bool offline;
  final DateTime? cachedAt;

  const IncidentResult({
    required this.records,
    required this.offline,
    this.cachedAt,
  });
}

class IncidentService {
  final http.Client _client;
  final List<String> _baseUrls;

  IncidentService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrls = resolveMonitoringApiBaseUrls(overrideBaseUrl: baseUrl);

  Future<IncidentResult> getIncidents({String status = 'all'}) async {
    const cacheKey = 'incidents:all';
    Object? lastError;
    for (final baseUrl in prioritizeMonitoringBaseUrls(_baseUrls)) {
      try {
        final uri = Uri.parse(
          '$baseUrl/incidents.php',
        ).replace(queryParameters: {'status': status});
        final response = await _client
            .get(uri)
            .timeout(monitoringApiTimeoutFor(baseUrl));
        final decoded = jsonDecode(response.body);
        if (response.statusCode != 200 ||
            decoded is! Map<String, dynamic> ||
            decoded['success'] != true ||
            decoded['data'] is! Map) {
          throw StateError('Incident API returned invalid data');
        }
        final data = Map<String, dynamic>.from(decoded['data'] as Map);
        await OfflineCacheService.writeJson(cacheKey, data);
        rememberMonitoringBaseUrl(baseUrl);
        return IncidentResult(
          records: _records(data),
          offline: false,
          cachedAt: DateTime.now(),
        );
      } catch (error) {
        lastError = error;
      }
    }

    final cached = await OfflineCacheService.readJson(cacheKey);
    if (cached is Map) {
      return IncidentResult(
        records: _records(Map<String, dynamic>.from(cached)),
        offline: true,
        cachedAt: await OfflineCacheService.lastUpdated(cacheKey),
      );
    }
    throw StateError('Riwayat gangguan belum tersedia: $lastError');
  }

  static List<Incident> _records(Map<String, dynamic> data) {
    final records = data['records'];
    if (records is! List) return [];
    return records
        .whereType<Map>()
        .map((record) => Incident.fromJson(Map<String, dynamic>.from(record)))
        .toList();
  }

  void dispose() => _client.close();
}
