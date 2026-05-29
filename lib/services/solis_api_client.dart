import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config/app_constants.dart';
import '../models/station.dart';
import '../models/station_detail.dart';
import '../models/inverter.dart';
import '../models/energy_data.dart';
import '../models/collector.dart';
import '../models/battery.dart';
import '../models/alarm.dart';

class SolisApiClient {
  final String _keyId;
  final String _keySecret;
  final String _baseUrl;
  final String _proxyUrl;
  final http.Client _httpClient;

  // Global rate-limit queue shared across ALL SolisApiClient instances.
  // SolisCloud allows at most 3 req / 5 s; we enforce one per 1.8 s (≈ 3.3/6 s).
  static Future<void> _rateLimitQueue = Future.value();
  static final List<DateTime> _requestStarts = [];
  static const int _maxRequestsPerWindow = 3;
  static const Duration _rateLimitWindow = Duration(seconds: 5);
  static const Duration _cacheTtl = Duration(seconds: 15);
  static const int _maxRetries = 3;

  static final Map<String, _CachedSolisResponse> _responseCache = {};
  static final Map<String, Future<Map<String, dynamic>>> _inFlightRequests = {};

  SolisApiClient({
    String? keyId,
    String? keySecret,
    String? baseUrl,
    String? proxyUrl,
    http.Client? httpClient,
  }) : _keyId = (keyId ?? dotenv.env['SOLIS_API_KEY'] ?? '').trim(),
       _keySecret = (keySecret ?? dotenv.env['SOLIS_API_SECRET'] ?? '').trim(),
       _baseUrl =
           (baseUrl ?? dotenv.env['SOLIS_API_URL'] ?? AppConstants.baseUrl)
               .trim(),
       _proxyUrl =
           (proxyUrl ??
                   dotenv.env['SOLIS_PROXY_URL'] ??
                   AppConstants.defaultProxyUrl)
               .trim(),
       _httpClient = httpClient ?? http.Client();

  List<dynamic> _extractRecords(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is! Map) return [];

    if (data['page'] is Map) {
      final page = data['page'];
      if (page['records'] is List) return page['records'] as List;
      if (page['data'] is List) return page['data'] as List;
      if (page['list'] is List) return page['list'] as List;
    }

    if (data['records'] is List) return data['records'] as List;
    if (data['data'] is List) return data['data'] as List;
    if (data['list'] is List) return data['list'] as List;
    if (data['rows'] is List) return data['rows'] as List;
    if (data['inverterStatusVo'] is List) {
      return data['inverterStatusVo'] as List;
    }
    if (data['stationStatusVo'] is List) return data['stationStatusVo'] as List;

    return [];
  }

  int _extractTotal(dynamic data) {
    if (data is! Map) return 0;

    if (data['page'] is Map) {
      final total = data['page']['total'];
      if (total is num) return total.toInt();
      if (total is String) return int.tryParse(total) ?? 0;
    }

    final total = data['total'];
    if (total is num) return total.toInt();
    if (total is String) return int.tryParse(total) ?? 0;

    return 0;
  }

  List<Battery> _deriveBatteriesFromInverters(List<Inverter> inverters) {
    final seen = <String>{};

    return inverters
        .where((inv) {
          // Conservative fallback:
          // Some Solis tenants include battery fields for all inverters with 0 values.
          // Treat as battery device only when SOC is positive and there is battery activity.
          final soc = inv.batteryCapacitySoc;
          final hasSoc = soc != null && soc > 0;
          final hasBatteryActivity =
              (inv.batteryPower != null &&
                  inv.batteryPower!.abs() > 0.000001) ||
              (inv.batteryTotalChargeEnergy != null &&
                  inv.batteryTotalChargeEnergy!.abs() > 0.000001) ||
              (inv.batteryTotalDischargeEnergy != null &&
                  inv.batteryTotalDischargeEnergy!.abs() > 0.000001);

          if (!(hasSoc && hasBatteryActivity)) return false;

          final key = inv.sn.trim();
          if (key.isEmpty || seen.contains(key)) return false;
          seen.add(key);
          return true;
        })
        .map(Battery.fromInverter)
        .toList();
  }

  // ─── HMAC-SHA1 Authentication ─────────────────────────────────────

  /// Generate Content-MD5: Base64(MD5(body))
  String _generateContentMd5(String body) {
    final bytes = utf8.encode(body);
    final digest = md5.convert(bytes);
    return base64Encode(digest.bytes);
  }

  /// Generate GMT Date string for HTTP header
  String _generateDateString() {
    final now = DateTime.now().toUtc();
    final formatter = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US');
    return formatter.format(now);
  }

  /// Generate HMAC-SHA1 Signature
  /// Sign = base64(HmacSHA1(KeySecret, VERB + "\n" + Content-MD5 + "\n" + Content-Type + "\n" + Date + "\n" + CanonicalizedResource))
  String _generateSignature(
    String contentMd5,
    String date,
    String canonicalizedResource,
  ) {
    const contentType = 'application/json';
    final signatureString =
        'POST\n$contentMd5\n$contentType\n$date\n$canonicalizedResource';

    final hmacSha1 = Hmac(sha1, utf8.encode(_keySecret));
    final digest = hmacSha1.convert(utf8.encode(signatureString));
    return base64Encode(digest.bytes);
  }

  // ─── HTTP Request ─────────────────────────────────────────────────

  /// Low-level authenticated POST. No rate limiting or retry.
  Future<Map<String, dynamic>> _rawRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    if (_shouldUseProxy) {
      return _rawProxyRequest(endpoint, body);
    }

    final bodyStr = jsonEncode(body);
    final contentMd5 = _generateContentMd5(bodyStr);
    final date = _generateDateString();
    final signature = _generateSignature(contentMd5, date, endpoint);

    final uri = Uri.parse('$_baseUrl$endpoint');

    try {
      final response = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Content-MD5': contentMd5,
          'Date': date,
          'Authorization': 'API $_keyId:$signature',
        },
        body: bodyStr,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true || data['code'] == '0') {
          return data;
        } else {
          throw SolisApiException(
            code: data['code']?.toString() ?? 'UNKNOWN',
            message: data['msg']?.toString() ?? 'Unknown API error',
          );
        }
      } else if (response.statusCode == 429) {
        throw SolisApiException(
          code: '429',
          message: 'Rate limit exceeded. Please wait before retrying.',
        );
      } else {
        throw SolisApiException(
          code: response.statusCode.toString(),
          message: 'HTTP Error: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      if (e is SolisApiException) rethrow;
      throw SolisApiException(
        code: 'NETWORK',
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  bool get _shouldUseProxy {
    return _proxyUrl.isNotEmpty &&
        (kIsWeb || _keyId.isEmpty || _keySecret.isEmpty);
  }

  Future<Map<String, dynamic>> _rawProxyRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'endpoint': endpoint, 'body': body}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['success'] == true || data['code'] == '0') {
          return data;
        } else {
          throw SolisApiException(
            code: data['code']?.toString() ?? 'UNKNOWN',
            message:
                data['msg']?.toString() ??
                data['message']?.toString() ??
                'Unknown API error',
          );
        }
      } else if (response.statusCode == 429) {
        throw SolisApiException(
          code: '429',
          message: 'Rate limit exceeded. Please wait before retrying.',
        );
      } else {
        throw SolisApiException(
          code: response.statusCode.toString(),
          message: 'Proxy HTTP Error: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      if (e is SolisApiException) rethrow;
      throw SolisApiException(
        code: 'NETWORK',
        message: 'Proxy network error: ${e.toString()}',
      );
    }
  }

  /// Retry wrapper: retries on 429 with exponential backoff.
  Future<Map<String, dynamic>> _requestWithRetry(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _rawRequest(endpoint, body);
      } on SolisApiException catch (e) {
        if (e.code == '429' && attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: 6 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }
    throw SolisApiException(
      code: 'MAX_RETRIES',
      message: 'Max retries exceeded',
    );
  }

  String _requestCacheKey(String endpoint, Map<String, dynamic> body) {
    return '$endpoint:${jsonEncode(body)}';
  }

  static void _pruneRequestStarts(DateTime now) {
    _requestStarts.removeWhere(
      (startedAt) => now.difference(startedAt) >= _rateLimitWindow,
    );
  }

  static Future<void> _waitForRateLimitSlot() {
    final completer = Completer<void>();
    _rateLimitQueue = _rateLimitQueue.then((_) async {
      while (true) {
        final now = DateTime.now();
        _pruneRequestStarts(now);

        if (_requestStarts.length < _maxRequestsPerWindow) {
          _requestStarts.add(now);
          completer.complete();
          return;
        }

        final oldest = _requestStarts.first;
        final wait = _rateLimitWindow - now.difference(oldest);
        await Future.delayed(wait + const Duration(milliseconds: 80));
      }
    });
    return completer.future;
  }

  /// Rate-limited request: all calls across all client instances share one
  /// rolling-window limiter. Identical requests also share the same in-flight
  /// future and a very short cache, which avoids duplicate Solis calls when
  /// dashboard, overview, and battery fallback request the same list together.
  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    final cacheKey = _requestCacheKey(endpoint, body);
    final cached = _responseCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached.data);
    }

    final inFlight = _inFlightRequests[cacheKey];
    if (inFlight != null) return inFlight;

    final request = () async {
      await _waitForRateLimitSlot();
      final response = await _requestWithRetry(endpoint, body);
      _responseCache[cacheKey] = _CachedSolisResponse(response, DateTime.now());
      return response;
    }();

    _inFlightRequests[cacheKey] = request;
    request.whenComplete(() => _inFlightRequests.remove(cacheKey));
    return request;
  }

  // ─── API Methods ──────────────────────────────────────────────────

  /// Get list of user's power stations (plants) - single page
  Future<List<Station>> getUserStationList({
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final result = await _request(AppConstants.userStationList, {
      'pageNo': pageNo,
      'pageSize': pageSize,
    });

    final data = result['data'];
    if (data == null) return [];

    // Handle paginated response
    List<dynamic> records = [];
    if (data is Map) {
      if (data['page'] != null && data['page']['records'] != null) {
        records = data['page']['records'] as List;
      } else if (data['stationStatusVo'] != null) {
        // Some API versions return data differently
        records = [data];
      } else if (data['records'] != null) {
        records = data['records'] as List;
      }
    } else if (data is List) {
      records = data;
    }

    return records.map((json) => Station.fromJson(json)).toList();
  }

  /// Get total number of stations
  Future<int> getStationTotal() async {
    final result = await _request(AppConstants.userStationList, {
      'pageNo': 1,
      'pageSize': 1,
    });

    final data = result['data'];
    if (data == null) return 0;
    if (data is Map) {
      if (data['page'] != null && data['page']['total'] != null) {
        return (data['page']['total'] as num).toInt();
      }
      if (data['total'] != null) {
        return (data['total'] as num).toInt();
      }
    }
    return 0;
  }

  /// Get ALL stations across all pages
  Future<List<Station>> getAllStations() async {
    const int pageSize = 100;
    List<Station> allStations = [];

    // First request to get the total
    final firstResult = await _request(AppConstants.userStationList, {
      'pageNo': 1,
      'pageSize': pageSize,
    });

    final data = firstResult['data'];
    if (data == null) return [];

    int total = 0;
    List<dynamic> firstRecords = [];

    if (data is Map) {
      if (data['page'] != null) {
        final page = data['page'];
        total = (page['total'] as num?)?.toInt() ?? 0;
        if (page['records'] != null) {
          firstRecords = page['records'] as List;
        }
      } else if (data['total'] != null) {
        total = (data['total'] as num).toInt();
        if (data['records'] != null) {
          firstRecords = data['records'] as List;
        }
      }
    }

    allStations.addAll(firstRecords.map((json) => Station.fromJson(json)));

    // Calculate remaining pages
    if (total > pageSize) {
      final totalPages = (total / pageSize).ceil();
      for (int page = 2; page <= totalPages; page++) {
        try {
          final stations = await getUserStationList(
            pageNo: page,
            pageSize: pageSize,
          );
          allStations.addAll(stations);
        } catch (_) {
          continue;
        }
      }
    }

    return allStations;
  }

  /// Get detailed information for a specific station
  Future<StationDetail> getStationDetail(String stationId) async {
    final result = await _request(AppConstants.stationDetail, {
      'id': stationId,
    });

    final data = result['data'];
    if (data == null) {
      throw SolisApiException(
        code: 'NO_DATA',
        message: 'No station detail data returned',
      );
    }

    return StationDetail.fromJson(data is Map<String, dynamic> ? data : {});
  }

  /// Get list of inverters for a station
  Future<List<Inverter>> getInverterList({
    String? stationId,
    int pageNo = 1,
    int pageSize = 20,
  }) async {
    final body = <String, dynamic>{'pageNo': pageNo, 'pageSize': pageSize};

    if (stationId != null) {
      body['stationId'] = stationId;
    }

    final result = await _request(AppConstants.inverterList, body);

    final data = result['data'];
    if (data == null) return [];

    final records = _extractRecords(data);

    return records.map((json) => Inverter.fromJson(json)).toList();
  }

  /// Get inverter detail by serial number
  Future<Inverter> getInverterDetail(String sn) async {
    final result = await _request(AppConstants.inverterDetail, {'sn': sn});

    final data = result['data'];
    if (data == null) {
      throw SolisApiException(
        code: 'NO_DATA',
        message: 'No inverter detail data returned',
      );
    }

    return Inverter.fromJson(data is Map<String, dynamic> ? data : {});
  }

  /// Get daily energy chart data (real-time power for a day)
  /// Uses /v1/api/stationDay which returns power data points
  Future<List<EnergyData>> getStationDayEnergy({
    required String stationId,
    required String date, // YYYY-MM-DD format
    String money = 'IDR',
    int timeZone = 7, // WIB = UTC+7
  }) async {
    final result = await _request(AppConstants.stationDay, {
      'id': stationId,
      'money': money,
      'time': date,
      'timeZone': timeZone,
    });

    final data = result['data'];
    if (data == null) return [];

    List<dynamic> records = [];
    if (data is List) {
      records = data;
    } else if (data is Map) {
      if (data['records'] != null) {
        records = data['records'] as List;
      }
    }

    return records.map((json) => EnergyData.fromJson(json)).toList();
  }

  /// Get monthly energy chart data (daily energy for a month)
  /// Uses /v1/api/stationMonth
  Future<List<EnergyData>> getStationMonthEnergy({
    required String stationId,
    required String month, // YYYY-MM format
    String money = 'IDR',
    int timeZone = 7,
  }) async {
    final result = await _request(AppConstants.stationMonth, {
      'id': stationId,
      'money': money,
      'time': month,
      'timeZone': timeZone,
    });

    final data = result['data'];
    if (data == null) return [];

    List<dynamic> records = [];
    if (data is List) {
      records = data;
    } else if (data is Map) {
      records = _extractRecords(data);
    }

    return records.map((json) => EnergyData.fromJson(json)).toList();
  }

  /// Get yearly energy chart data (monthly energy for a year)
  /// Uses /v1/api/stationYear
  Future<List<EnergyData>> getStationYearEnergy({
    required String stationId,
    required String year, // YYYY format
    String money = 'IDR',
    int timeZone = 7,
  }) async {
    final result = await _request(AppConstants.stationYear, {
      'id': stationId,
      'money': money,
      'time': year,
      'timeZone': timeZone,
    });

    final data = result['data'];
    if (data == null) return [];

    List<dynamic> records = [];
    if (data is List) {
      records = data;
    } else if (data is Map) {
      records = _extractRecords(data);
    }

    return records.map((json) => EnergyData.fromJson(json)).toList();
  }

  // ─── Inverter (all pages) ────────────────────────────────────────

  /// Get ALL inverters across all pages
  Future<List<Inverter>> getAllInverters() async {
    const int pageSize = 100;
    List<Inverter> all = [];

    final firstResult = await _request(AppConstants.inverterList, {
      'pageNo': 1,
      'pageSize': pageSize,
    });
    final data = firstResult['data'];
    if (data == null) return [];

    final total = _extractTotal(data);
    final firstRecords = _extractRecords(data);
    all.addAll(firstRecords.map((j) => Inverter.fromJson(j)));

    if (total > pageSize) {
      final pages = (total / pageSize).ceil();
      for (int p = 2; p <= pages; p++) {
        try {
          final inv = await getInverterList(pageNo: p, pageSize: pageSize);
          all.addAll(inv);
        } catch (_) {
          continue;
        }
      }
    }
    return all;
  }

  // ─── Collector / Datalogger ──────────────────────────────────────

  Future<List<Collector>> getCollectorList({
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    final result = await _request(AppConstants.collectorList, {
      'pageNo': pageNo,
      'pageSize': pageSize,
    });
    final data = result['data'];
    if (data == null) return [];
    final records = _extractRecords(data);
    return records.map((j) => Collector.fromJson(j)).toList();
  }

  Future<List<Collector>> getAllCollectors() async {
    const int pageSize = 100;
    List<Collector> all = [];
    final firstResult = await _request(AppConstants.collectorList, {
      'pageNo': 1,
      'pageSize': pageSize,
    });
    final data = firstResult['data'];
    if (data == null) return [];
    final total = _extractTotal(data);
    final firstRecords = _extractRecords(data);
    all.addAll(firstRecords.map((j) => Collector.fromJson(j)));
    if (total > pageSize) {
      final pages = (total / pageSize).ceil();
      for (int p = 2; p <= pages; p++) {
        try {
          final c = await getCollectorList(pageNo: p, pageSize: pageSize);
          all.addAll(c);
        } catch (_) {
          continue;
        }
      }
    }
    return all;
  }

  Future<Collector> getCollectorDetail(String sn) async {
    final result = await _request(AppConstants.collectorDetail, {'sn': sn});
    final data = result['data'];
    if (data == null) {
      throw SolisApiException(code: 'NO_DATA', message: 'No collector data');
    }
    return Collector.fromJson(data is Map<String, dynamic> ? data : {});
  }

  // ─── Battery / EPM ──────────────────────────────────────────────

  Future<List<Battery>> getBatteryList({
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    try {
      final result = await _request(AppConstants.epmList, {
        'pageNo': pageNo,
        'pageSize': pageSize,
      });
      final data = result['data'];
      final records = _extractRecords(data);
      if (records.isNotEmpty) {
        return records.map((j) => Battery.fromJson(j)).toList();
      }
    } on SolisApiException {
      if (pageNo != 1) {
        rethrow;
      }
    }

    if (pageNo != 1) return [];

    final fallbackInverters = await getInverterList(
      pageNo: 1,
      pageSize: pageSize,
    );
    return _deriveBatteriesFromInverters(fallbackInverters);
  }

  Future<List<Battery>> getAllBatteries() async {
    const int pageSize = 100;
    List<Battery> all = [];
    try {
      final firstResult = await _request(AppConstants.epmList, {
        'pageNo': 1,
        'pageSize': pageSize,
      });
      final data = firstResult['data'];
      final total = _extractTotal(data);
      final firstRecords = _extractRecords(data);
      all.addAll(firstRecords.map((j) => Battery.fromJson(j)));
      if (total > pageSize) {
        final pages = (total / pageSize).ceil();
        for (int p = 2; p <= pages; p++) {
          try {
            final b = await getBatteryList(pageNo: p, pageSize: pageSize);
            all.addAll(b);
          } catch (_) {
            continue;
          }
        }
      }
    } on SolisApiException {
      // Some Solis accounts expose battery metrics only through hybrid inverter data.
    }

    if (all.isNotEmpty) return all;

    final fallbackInverters = await getAllInverters();
    return _deriveBatteriesFromInverters(fallbackInverters);
  }

  // ─── Utility ────────────────────────────────────────────────────

  Future<List<Alarm>> getAlarmList({int pageNo = 1, int pageSize = 100}) async {
    final result = await _request(AppConstants.alarmList, {
      'pageNo': pageNo,
      'pageSize': pageSize,
    });
    final data = result['data'];
    if (data == null) return [];
    final records = _extractRecords(data);
    return records.map((j) => Alarm.fromJson(j)).toList();
  }

  Future<List<Alarm>> getAllAlarms() async {
    const int pageSize = 100;
    List<Alarm> all = [];
    final firstResult = await _request(AppConstants.alarmList, {
      'pageNo': 1,
      'pageSize': pageSize,
    });
    final data = firstResult['data'];
    if (data == null) return [];
    final total = _extractTotal(data);
    final firstRecords = _extractRecords(data);
    all.addAll(firstRecords.map((j) => Alarm.fromJson(j)));
    if (total > pageSize) {
      final pages = (total / pageSize).ceil();
      for (int p = 2; p <= pages; p++) {
        try {
          final b = await getAlarmList(pageNo: p, pageSize: pageSize);
          all.addAll(b);
        } catch (_) {
          continue;
        }
      }
    }
    return all;
  }

  Future<bool> testConnection() async {
    try {
      await getUserStationList(pageNo: 1, pageSize: 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

// ─── Exception ────────────────────────────────────────────────────

class _CachedSolisResponse {
  final Map<String, dynamic> data;
  final DateTime createdAt;

  _CachedSolisResponse(this.data, this.createdAt);

  bool get isExpired {
    return DateTime.now().difference(createdAt) >= SolisApiClient._cacheTtl;
  }
}

class SolisApiException implements Exception {
  final String code;
  final String message;

  SolisApiException({required this.code, required this.message});

  @override
  String toString() => 'SolisApiException [$code]: $message';
}
