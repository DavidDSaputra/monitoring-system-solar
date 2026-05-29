import '../models/alarm.dart';
import '../models/battery.dart';
import '../models/collector.dart';
import '../models/energy_data.dart';
import '../models/inverter.dart';
import '../models/monitoring_overview.dart';
import '../models/station.dart';
import '../models/station_detail.dart';
import '../providers/default_monitoring_provider.dart';
import '../providers/monitoring_provider.dart';

class MonitoringRepository {
  final MonitoringProvider _provider;
  final bool _ownsProvider;

  static final MonitoringProvider _defaultProvider =
      createDefaultMonitoringProvider();
  static final Map<String, _CacheEntry<Object>> _cache = {};
  static final Map<String, Future<Object>> _inFlight = {};

  MonitoringRepository({MonitoringProvider? provider})
    : _provider = provider ?? _defaultProvider,
      _ownsProvider = provider != null;

  String get providerId => _provider.id;
  String get providerName => _provider.displayName;

  Future<List<Station>> getPlants({bool forceRefresh = false}) {
    return _cached(
      'plants',
      const Duration(seconds: 20),
      _provider.getPlants,
      forceRefresh: forceRefresh,
    );
  }

  Future<StationDetail> getPlantDetail(
    String stationId, {
    bool forceRefresh = false,
  }) {
    return _cached(
      'plant-detail:$stationId',
      const Duration(seconds: 20),
      () => _provider.getPlantDetail(stationId),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Inverter>> getInverters({
    String? stationId,
    bool forceRefresh = false,
  }) {
    final scopedStationId = stationId?.trim();
    return _cached(
      'inverters:${scopedStationId ?? 'all'}',
      const Duration(seconds: 25),
      () => _provider.getInverters(stationId: scopedStationId),
      forceRefresh: forceRefresh,
    );
  }

  Future<Inverter> getInverterDetail(String sn, {bool forceRefresh = false}) {
    return _cached(
      'inverter-detail:$sn',
      const Duration(seconds: 15),
      () => _provider.getInverterDetail(sn),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Battery>> getBatteries({bool forceRefresh = false}) {
    return _cached(
      'batteries',
      const Duration(seconds: 25),
      _provider.getBatteries,
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Collector>> getCollectors({
    String? stationId,
    bool forceRefresh = false,
  }) async {
    final collectors = await _cached(
      'collectors',
      const Duration(seconds: 30),
      _provider.getCollectors,
      forceRefresh: forceRefresh,
    );

    final scopedStationId = stationId?.trim();
    if (scopedStationId == null || scopedStationId.isEmpty) return collectors;

    final filtered = collectors
        .where((collector) => collector.stationId == scopedStationId)
        .toList();
    return filtered.isNotEmpty ? filtered : collectors;
  }

  Future<Collector> getCollectorDetail(String sn, {bool forceRefresh = false}) {
    return _cached(
      'collector-detail:$sn',
      const Duration(seconds: 15),
      () => _provider.getCollectorDetail(sn),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<Alarm>> getAlarms({
    String? stationId,
    bool forceRefresh = false,
  }) async {
    final alarms = await _cached(
      'alarms',
      const Duration(seconds: 30),
      _provider.getAlarms,
      forceRefresh: forceRefresh,
    );

    final scopedStationId = stationId?.trim();
    if (scopedStationId == null || scopedStationId.isEmpty) return alarms;

    final filtered = alarms
        .where((alarm) => alarm.stationId == scopedStationId)
        .toList();
    return filtered.isNotEmpty ? filtered : alarms;
  }

  Future<List<EnergyData>> getStationDayEnergy({
    required String stationId,
    required String date,
    bool forceRefresh = false,
  }) {
    return _cached(
      'station-day:$stationId:$date',
      const Duration(minutes: 1),
      () => _provider.getStationDayEnergy(stationId: stationId, date: date),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<EnergyData>> getStationMonthEnergy({
    required String stationId,
    required String month,
    bool forceRefresh = false,
  }) {
    return _cached(
      'station-month:$stationId:$month',
      const Duration(minutes: 5),
      () => _provider.getStationMonthEnergy(stationId: stationId, month: month),
      forceRefresh: forceRefresh,
    );
  }

  Future<List<EnergyData>> getStationYearEnergy({
    required String stationId,
    required String year,
    bool forceRefresh = false,
  }) {
    return _cached(
      'station-year:$stationId:$year',
      const Duration(minutes: 10),
      () => _provider.getStationYearEnergy(stationId: stationId, year: year),
      forceRefresh: forceRefresh,
    );
  }

  Future<MonitoringOverviewSnapshot> getOverview({bool forceRefresh = false}) {
    return _cached(
      'overview',
      const Duration(seconds: 20),
      _provider.getOverview,
      forceRefresh: forceRefresh,
    );
  }

  Future<T> _cached<T>(
    String key,
    Duration ttl,
    Future<T> Function() load, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$providerId:$key';
    final cached = _cache[cacheKey];
    final now = DateTime.now();

    if (!forceRefresh && cached != null && !cached.isExpired(now)) {
      return cached.data as T;
    }

    if (!forceRefresh) {
      final inFlight = _inFlight[cacheKey];
      if (inFlight != null) return await inFlight as T;
    }

    final request = load().then<Object>((value) {
      _cache[cacheKey] = _CacheEntry<Object>(
        value as Object,
        DateTime.now(),
        ttl,
      );
      return value as Object;
    });

    _inFlight[cacheKey] = request;
    try {
      return await request as T;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  void dispose() {
    if (_ownsProvider) {
      _provider.dispose();
    }
  }
}

class _CacheEntry<T extends Object> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  const _CacheEntry(this.data, this.createdAt, this.ttl);

  bool isExpired(DateTime now) {
    return now.difference(createdAt) >= ttl;
  }
}
