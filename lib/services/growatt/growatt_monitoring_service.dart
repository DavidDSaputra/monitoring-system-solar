import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_base_urls.dart';
import '../../models/growatt/growatt_device.dart';
import '../../models/growatt/growatt_plant.dart';
import '../../models/growatt/growatt_power_point.dart';

class GrowattMonitoringService {
  final List<String> _baseUrls;
  final http.Client _httpClient;
  static final Map<String, dynamic> _lastGoodData = {};

  GrowattMonitoringService({String? baseUrl, http.Client? httpClient})
    : _baseUrls = _resolveBaseUrls(baseUrl),
      _httpClient = httpClient ?? http.Client();

  Future<List<GrowattPlant>> getPlants() async {
    final data = await _get('growatt/plants.php');
    return _list(data).map(GrowattPlant.fromJson).toList();
  }

  Future<GrowattPlant> getRealtimePlant(String plantCode) async {
    final data = await _get('growatt/station_realtime.php', {
      'plantCode': plantCode,
    });
    return GrowattPlant.fromJson(_map(data));
  }

  Future<List<GrowattDevice>> getDevices(String plantCode) async {
    final data = await _get('growatt/devices.php', {'plantCode': plantCode});
    return _list(data).map(GrowattDevice.fromJson).toList();
  }

  Future<List<GrowattPowerPoint>> getPowerPoints(String plantCode) async {
    final data = await _get('growatt/power.php', {'plantCode': plantCode});
    return _list(data).map(GrowattPowerPoint.fromJson).toList();
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    Object? lastError;
    final cacheKey = '$path:${jsonEncode(query ?? const <String, String>{})}';

    for (final baseUrl in prioritizeMonitoringBaseUrls(_baseUrls)) {
      try {
        final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
        final response = await _httpClient
            .get(uri)
            .timeout(monitoringApiTimeoutFor(baseUrl));
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const GrowattMonitoringException(
            'Backend returned invalid JSON',
          );
        }

        if (response.statusCode != 200 || decoded['success'] != true) {
          throw GrowattMonitoringException(
            decoded['message']?.toString() ??
                decoded['msg']?.toString() ??
                'Growatt data unavailable',
          );
        }

        rememberMonitoringBaseUrl(baseUrl);
        _lastGoodData[cacheKey] = decoded['data'];
        return decoded['data'];
      } catch (e) {
        lastError = e;
      }
    }

    if (_lastGoodData.containsKey(cacheKey)) {
      return _lastGoodData[cacheKey];
    }

    if (lastError is GrowattMonitoringException) throw lastError;
    throw GrowattMonitoringException('Growatt data unavailable: $lastError');
  }

  void dispose() => _httpClient.close();

  static List<String> _resolveBaseUrls(String? baseUrl) {
    return resolveMonitoringApiBaseUrls(overrideBaseUrl: baseUrl);
  }

  static List<Map<String, dynamic>> _list(dynamic data) {
    final records = data is Map<String, dynamic> ? data['records'] : data;
    if (records is! List) return [];
    return records
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}

class GrowattMonitoringException implements Exception {
  final String message;

  const GrowattMonitoringException(this.message);

  @override
  String toString() => message;
}
