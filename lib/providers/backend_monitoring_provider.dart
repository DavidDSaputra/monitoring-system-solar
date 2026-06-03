import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_base_urls.dart';
import '../models/alarm.dart';
import '../models/battery.dart';
import '../models/collector.dart';
import '../models/energy_data.dart';
import '../models/inverter.dart';
import '../models/monitoring_overview.dart';
import '../models/station.dart';
import '../models/station_detail.dart';
import 'monitoring_provider.dart';

class BackendMonitoringProvider implements MonitoringProvider {
  final List<String> _baseUrls;
  final http.Client _httpClient;

  BackendMonitoringProvider({String? baseUrl, http.Client? httpClient})
    : _baseUrls = _resolveBaseUrls(baseUrl),
      _httpClient = httpClient ?? http.Client();

  @override
  String get id => 'backend';

  @override
  String get displayName => 'Monitoring API';

  @override
  Future<List<Station>> getPlants({bool forceRefresh = false}) async {
    final data = await _getData(
      'plants.php',
      forceRefresh ? {'refresh': 'true'} : null,
    );
    return _records(data).map((json) => Station.fromJson(json)).toList();
  }

  @override
  Future<MonitoringOverviewSnapshot> getOverview() async {
    final data = await _getData('overview.php');
    return MonitoringOverviewSnapshot(
      plants: _sectionRecords(
        data,
        'plants',
      ).map((json) => Station.fromJson(json)).toList(),
      inverters: _sectionRecords(
        data,
        'inverters',
      ).map((json) => Inverter.fromJson(json)).toList(),
      batteries: _sectionRecords(
        data,
        'batteries',
      ).map((json) => Battery.fromJson(json)).toList(),
      collectors: _sectionRecords(
        data,
        'collectors',
      ).map((json) => Collector.fromJson(json)).toList(),
    );
  }

  @override
  Future<StationDetail> getPlantDetail(String stationId) async {
    final data = await _getData('station_detail.php', {'id': stationId});
    return StationDetail.fromJson(data);
  }

  @override
  Future<List<Inverter>> getInverters({String? stationId}) async {
    final query = stationId?.trim().isNotEmpty == true
        ? {'stationId': stationId!.trim()}
        : null;
    final data = await _getData('inverters.php', query);
    return _records(data).map((json) => Inverter.fromJson(json)).toList();
  }

  @override
  Future<Inverter> getInverterDetail(String sn) async {
    final data = await _getData('inverter_detail.php', {'sn': sn});
    return Inverter.fromJson(data);
  }

  @override
  Future<List<Battery>> getBatteries() async {
    final data = await _getData('batteries.php');
    return _records(data).map((json) => Battery.fromJson(json)).toList();
  }

  @override
  Future<List<Collector>> getCollectors() async {
    final data = await _getData('collectors.php');
    return _records(data).map((json) => Collector.fromJson(json)).toList();
  }

  @override
  Future<Collector> getCollectorDetail(String sn) async {
    final data = await _getData('collector_detail.php', {'sn': sn});
    return Collector.fromJson(data);
  }

  @override
  Future<List<Alarm>> getAlarms() async {
    final data = await _getData('alarms.php');
    return _records(data).map((json) => Alarm.fromJson(json)).toList();
  }

  @override
  Future<List<EnergyData>> getStationDayEnergy({
    required String stationId,
    required String date,
  }) {
    return _getStationEnergy(scope: 'day', stationId: stationId, time: date);
  }

  @override
  Future<List<EnergyData>> getStationMonthEnergy({
    required String stationId,
    required String month,
  }) {
    return _getStationEnergy(scope: 'month', stationId: stationId, time: month);
  }

  @override
  Future<List<EnergyData>> getStationYearEnergy({
    required String stationId,
    required String year,
  }) {
    return _getStationEnergy(scope: 'year', stationId: stationId, time: year);
  }

  Future<List<EnergyData>> _getStationEnergy({
    required String scope,
    required String stationId,
    required String time,
  }) async {
    final data = await _getData('station_energy.php', {
      'scope': scope,
      'stationId': stationId,
      'time': time,
    });
    return _records(data).map((json) => EnergyData.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> _getData(
    String path, [
    Map<String, String>? query,
  ]) async {
    Object? lastError;

    for (final baseUrl in prioritizeMonitoringBaseUrls(_baseUrls)) {
      try {
        final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
        final isLiveRefresh = query?['refresh'] == 'true';
        final response = await _httpClient
            .get(uri)
            .timeout(
              isLiveRefresh
                  ? const Duration(seconds: 35)
                  : monitoringApiTimeoutFor(baseUrl),
            );
        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw BackendMonitoringException(
            code: response.statusCode.toString(),
            message: 'Monitoring API returned invalid JSON from $baseUrl',
          );
        }

        if (response.statusCode != 200 || decoded['success'] != true) {
          throw BackendMonitoringException(
            code: (decoded['code'] ?? response.statusCode).toString(),
            message:
                decoded['message']?.toString() ??
                decoded['msg']?.toString() ??
                'Monitoring API request failed from $baseUrl',
          );
        }

        final data = decoded['data'];
        rememberMonitoringBaseUrl(baseUrl);
        if (data is Map<String, dynamic>) return data;
        return <String, dynamic>{};
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError is BackendMonitoringException) {
      throw lastError;
    }

    throw BackendMonitoringException(
      code: 'NETWORK',
      message:
          'Monitoring API tidak bisa dihubungi. Cek Laragon/Apache, firewall, Wi-Fi, atau jalankan adb reverse tcp:8080 tcp:80. Detail: $lastError',
    );
  }

  static List<String> _resolveBaseUrls(String? baseUrl) {
    return resolveMonitoringApiBaseUrls(overrideBaseUrl: baseUrl);
  }

  List<Map<String, dynamic>> _records(Map<String, dynamic> data) {
    final records = data['records'];
    if (records is! List) return [];

    return records
        .whereType<Map>()
        .map((json) => Map<String, dynamic>.from(json))
        .toList();
  }

  List<Map<String, dynamic>> _sectionRecords(
    Map<String, dynamic> data,
    String section,
  ) {
    final value = data[section];
    if (value is! Map<String, dynamic>) return [];
    return _records(value);
  }

  @override
  void dispose() {
    _httpClient.close();
  }
}

class BackendMonitoringException implements Exception {
  final String code;
  final String message;

  const BackendMonitoringException({required this.code, required this.message});

  @override
  String toString() => 'BackendMonitoringException [$code]: $message';
}
