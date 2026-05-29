import 'battery.dart';
import 'collector.dart';
import 'inverter.dart';
import 'station.dart';

class MonitoringOverviewSnapshot {
  final List<Station> plants;
  final List<Inverter> inverters;
  final List<Battery> batteries;
  final List<Collector> collectors;

  const MonitoringOverviewSnapshot({
    required this.plants,
    required this.inverters,
    required this.batteries,
    required this.collectors,
  });
}
