import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_base_urls.dart';
import '../../models/huawei/huawei_alarm.dart';
import '../../models/huawei/huawei_device.dart';
import '../../models/huawei/huawei_plant.dart';

enum MonitoringSourceFilter { all, solis, huawei }

class HuaweiMonitoringService {
  final List<String> _baseUrls;
  final http.Client _httpClient;
  static final Map<String, dynamic> _lastGoodData = {};

  HuaweiMonitoringService({String? baseUrl, http.Client? httpClient})
    : _baseUrls = _resolveBaseUrls(baseUrl),
      _httpClient = httpClient ?? http.Client();

  Future<List<HuaweiPlant>> getPlants({
    MonitoringSourceFilter source = MonitoringSourceFilter.huawei,
  }) async {
    final data = source == MonitoringSourceFilter.huawei
        ? await _get('huawei/plants.php')
        : await _get('monitoring/plants.php', {'source': source.name});
    return _list(data).map(HuaweiPlant.fromJson).toList();
  }

  Future<HuaweiPlant> getRealtimePlant(String plantCode) async {
    final data = await _get('huawei/station_realtime.php', {
      'plantCode': plantCode,
    });
    final map = _map(data);
    return HuaweiPlant.fromJson(map);
  }

  Future<List<HuaweiDevice>> getDevices(String plantCode) async {
    final data = await _get('huawei/devices.php', {'plantCode': plantCode});
    return _list(data).map(HuaweiDevice.fromJson).toList();
  }

  Future<List<HuaweiAlarm>> getAlarms({
    String? plantCode,
    bool historical = false,
  }) async {
    final query = <String, String>{
      if (plantCode?.isNotEmpty == true) 'plantCode': plantCode!,
      if (historical) 'historical': 'true',
    };
    final data = await _get('huawei/alarms.php', query);
    return _list(data).map(HuaweiAlarm.fromJson).toList();
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    Object? lastError;
    final cacheKey = '$path:${jsonEncode(query ?? const <String, String>{})}';

    for (final baseUrl in prioritizeMonitoringBaseUrls(_baseUrls)) {
      try {
        final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
        final response = await _httpClient
            .get(uri)
            .timeout(
              monitoringApiTimeoutFor(
                baseUrl,
                fallback: const Duration(seconds: 6),
              ),
            );
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw HuaweiMonitoringException('Backend returned invalid JSON');
        }

        if (response.statusCode != 200 || decoded['success'] != true) {
          throw HuaweiMonitoringException(
            decoded['message']?.toString() ??
                decoded['msg']?.toString() ??
                'Huawei data unavailable',
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

    if (lastError is HuaweiMonitoringException) throw lastError;
    throw HuaweiMonitoringException('Huawei data unavailable: $lastError');
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

class HuaweiMonitoringException implements Exception {
  final String message;

  const HuaweiMonitoringException(this.message);

  @override
  String toString() => message;
}
