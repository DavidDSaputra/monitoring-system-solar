import '../models/alarm.dart';
import '../models/battery.dart';
import '../models/collector.dart';
import '../models/energy_data.dart';
import '../models/inverter.dart';
import '../models/monitoring_overview.dart';
import '../models/station.dart';
import '../models/station_detail.dart';

abstract class MonitoringProvider {
  String get id;
  String get displayName;

  Future<List<Station>> getPlants({bool forceRefresh = false});
  Future<MonitoringOverviewSnapshot> getOverview();
  Future<StationDetail> getPlantDetail(String stationId);

  Future<List<Inverter>> getInverters({String? stationId});
  Future<Inverter> getInverterDetail(String sn);

  Future<List<Battery>> getBatteries();

  Future<List<Collector>> getCollectors();
  Future<Collector> getCollectorDetail(String sn);

  Future<List<Alarm>> getAlarms();

  Future<List<EnergyData>> getStationDayEnergy({
    required String stationId,
    required String date,
  });

  Future<List<EnergyData>> getStationMonthEnergy({
    required String stationId,
    required String month,
  });

  Future<List<EnergyData>> getStationYearEnergy({
    required String stationId,
    required String year,
  });

  void dispose();
}
