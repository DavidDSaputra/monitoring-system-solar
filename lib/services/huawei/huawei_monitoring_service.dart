import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../config/app_constants.dart';
import '../../models/huawei/huawei_device.dart';
import '../../models/huawei/huawei_plant.dart';

enum MonitoringSourceFilter { all, solis, huawei }

class HuaweiMonitoringService {
  final List<String> _baseUrls;
  final http.Client _httpClient;

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

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    Object? lastError;

    for (final baseUrl in _baseUrls) {
      try {
        final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
        final response = await _httpClient
            .get(uri)
            .timeout(const Duration(seconds: 12));
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

        return decoded['data'];
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError is HuaweiMonitoringException) throw lastError;
    throw HuaweiMonitoringException('Huawei data unavailable: $lastError');
  }

  void dispose() => _httpClient.close();

  static List<String> _resolveBaseUrls(String? baseUrl) {
    final configured = baseUrl ?? dotenv.env['MONITORING_API_BASE_URLS'];
    final rawUrls = configured?.trim().isNotEmpty == true
        ? configured!.split(',')
        : [
            dotenv.env['MONITORING_API_BASE_URL'] ??
                AppConstants.defaultMonitoringApiBaseUrl,
          ];

    final urls = rawUrls
        .map((url) => url.trim().replaceFirst(RegExp(r'/+$'), ''))
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    return urls.isEmpty ? [AppConstants.defaultMonitoringApiBaseUrl] : urls;
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
