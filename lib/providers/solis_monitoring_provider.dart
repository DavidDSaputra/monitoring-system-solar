import '../models/alarm.dart';
import '../models/battery.dart';
import '../models/collector.dart';
import '../models/energy_data.dart';
import '../models/inverter.dart';
import '../models/monitoring_overview.dart';
import '../models/station.dart';
import '../models/station_detail.dart';
import '../services/solis_api_client.dart';
import 'monitoring_provider.dart';

class SolisMonitoringProvider implements MonitoringProvider {
  final SolisApiClient _client;
  final bool _ownsClient;

  SolisMonitoringProvider({SolisApiClient? client})
    : _client = client ?? SolisApiClient(),
      _ownsClient = client == null;

  @override
  String get id => 'solis';

  @override
  String get displayName => 'Solis';

  @override
  Future<List<Station>> getPlants() {
    return _client.getAllStations();
  }

  @override
  Future<MonitoringOverviewSnapshot> getOverview() async {
    final results = await Future.wait([
      getPlants(),
      getInverters(),
      getBatteries(),
      getCollectors(),
    ]);

    return MonitoringOverviewSnapshot(
      plants: results[0] as List<Station>,
      inverters: results[1] as List<Inverter>,
      batteries: results[2] as List<Battery>,
      collectors: results[3] as List<Collector>,
    );
  }

  @override
  Future<StationDetail> getPlantDetail(String stationId) {
    return _client.getStationDetail(stationId);
  }

  @override
  Future<List<Inverter>> getInverters({String? stationId}) {
    if (stationId != null && stationId.trim().isNotEmpty) {
      return _client.getInverterList(stationId: stationId);
    }

    return _client.getAllInverters();
  }

  @override
  Future<Inverter> getInverterDetail(String sn) {
    return _client.getInverterDetail(sn);
  }

  @override
  Future<List<Battery>> getBatteries() {
    return _client.getAllBatteries();
  }

  @override
  Future<List<Collector>> getCollectors() {
    return _client.getAllCollectors();
  }

  @override
  Future<Collector> getCollectorDetail(String sn) {
    return _client.getCollectorDetail(sn);
  }

  @override
  Future<List<Alarm>> getAlarms() {
    return _client.getAllAlarms();
  }

  @override
  Future<List<EnergyData>> getStationDayEnergy({
    required String stationId,
    required String date,
  }) {
    return _client.getStationDayEnergy(stationId: stationId, date: date);
  }

  @override
  Future<List<EnergyData>> getStationMonthEnergy({
    required String stationId,
    required String month,
  }) {
    return _client.getStationMonthEnergy(stationId: stationId, month: month);
  }

  @override
  Future<List<EnergyData>> getStationYearEnergy({
    required String stationId,
    required String year,
  }) {
    return _client.getStationYearEnergy(stationId: stationId, year: year);
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }
}
