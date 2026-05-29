import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/battery.dart';
import '../models/collector.dart';
import '../models/inverter.dart';
import '../models/station.dart';
import 'collector_detail_screen.dart';
import 'inverter_data_screen.dart';
import 'plant_detail_screen.dart';

enum OverviewDetailType { plants, inverters, batteries, dataloggers }

class OverviewDetailScreen extends StatelessWidget {
  final OverviewDetailType type;
  final List<Station> stations;
  final List<Inverter> inverters;
  final List<Battery> batteries;
  final List<Collector> collectors;

  const OverviewDetailScreen.plants({
    super.key,
    required this.stations,
    this.inverters = const [],
    this.batteries = const [],
  }) : type = OverviewDetailType.plants,
       collectors = const [];

  const OverviewDetailScreen.inverters({super.key, required this.inverters})
    : type = OverviewDetailType.inverters,
      stations = const [],
      batteries = const [],
      collectors = const [];

  const OverviewDetailScreen.batteries({super.key, required this.batteries})
    : type = OverviewDetailType.batteries,
      stations = const [],
      inverters = const [],
      collectors = const [];

  const OverviewDetailScreen.dataloggers({super.key, required this.collectors})
    : type = OverviewDetailType.dataloggers,
      stations = const [],
      inverters = const [],
      batteries = const [];

  String get _title {
    switch (type) {
      case OverviewDetailType.plants:
        return 'All Plants';
      case OverviewDetailType.inverters:
        return 'All Inverters';
      case OverviewDetailType.batteries:
        return 'All Batteries';
      case OverviewDetailType.dataloggers:
        return 'All Dataloggers';
    }
  }

  String get _subtitle {
    switch (type) {
      case OverviewDetailType.plants:
        return '${stations.length} plant';
      case OverviewDetailType.inverters:
        return '${inverters.length} inverter';
      case OverviewDetailType.batteries:
        return '${batteries.length} battery';
      case OverviewDetailType.dataloggers:
        return '${collectors.length} datalogger';
    }
  }

  IconData get _icon {
    switch (type) {
      case OverviewDetailType.plants:
        return Icons.solar_power_rounded;
      case OverviewDetailType.inverters:
        return Icons.memory_rounded;
      case OverviewDetailType.batteries:
        return Icons.battery_charging_full_rounded;
      case OverviewDetailType.dataloggers:
        return Icons.router_rounded;
    }
  }

  int get _itemCount {
    switch (type) {
      case OverviewDetailType.plants:
        return stations.length;
      case OverviewDetailType.inverters:
        return inverters.length;
      case OverviewDetailType.batteries:
        return batteries.length;
      case OverviewDetailType.dataloggers:
        return collectors.length;
    }
  }

  String _stationKey(String? stationName) {
    if (stationName == null) return '';
    return stationName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _stationIdKey(String? stationId) {
    if (stationId == null) return '';
    final raw = stationId.trim();
    if (raw.isEmpty) return '';
    final asInt = int.tryParse(raw);
    return asInt?.toString() ?? raw;
  }

  bool _isSameStation({
    required Station station,
    String? deviceStationId,
    String? deviceStationName,
  }) {
    final stationId = _stationIdKey(station.id);
    final deviceId = _stationIdKey(deviceStationId);
    if (stationId.isNotEmpty && deviceId.isNotEmpty) {
      return stationId == deviceId;
    }

    final stationName = _stationKey(station.stationName);
    final deviceName = _stationKey(deviceStationName);
    if (stationName.isEmpty || deviceName.isEmpty) return false;
    return stationName == deviceName;
  }

  String _plantTypeLabel(Station station) {
    final hints = inverters
        .where(
          (inv) => _isSameStation(
            station: station,
            deviceStationId: inv.stationId,
            deviceStationName: inv.stationName,
          ),
        )
        .expand<String?>((inv) => [inv.productModel, inv.inverterName]);
    final stationBatteries = batteries
        .where(
          (battery) => _isSameStation(
            station: station,
            deviceStationId: battery.stationId,
            deviceStationName: battery.stationName,
          ),
        )
        .toList();
    final batterySocHints = stationBatteries
        .map((b) => b.batteryCapacitySoc)
        .whereType<double>()
        .toList();
    final batteryPowerHints = stationBatteries
        .map((b) => b.batteryPower)
        .whereType<double>()
        .toList();
    final gridImportHints = stationBatteries
        .map((b) => b.gridPurchasedTodayEnergy)
        .whereType<double>()
        .toList();
    final gridExportHints = stationBatteries
        .map((b) => b.gridSellTodayEnergy)
        .whereType<double>()
        .toList();
    final homeLoadHints = stationBatteries
        .map((b) => b.homeLoadTodayEnergy)
        .whereType<double>()
        .toList();

    return station.plantTypeLabel(
      inverterModelHints: hints,
      batteryDeviceCount: stationBatteries.length,
      batteryPercent: batterySocHints.isNotEmpty ? batterySocHints.first : null,
      batteryPower: batteryPowerHints.isNotEmpty
          ? batteryPowerHints.first
          : null,
      gridPurchasedDayEnergy: gridImportHints.isNotEmpty
          ? gridImportHints.first
          : null,
      gridSellDayEnergy: gridExportHints.isNotEmpty
          ? gridExportHints.first
          : null,
      homeLoadTodayEnergy: homeLoadHints.isNotEmpty
          ? homeLoadHints.first
          : null,
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.surfaceBorder),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (_itemCount == 0)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList.builder(
                itemCount: _itemCount,
                itemBuilder: (_, index) {
                  switch (type) {
                    case OverviewDetailType.plants:
                      return _buildPlantCard(context, stations[index]);
                    case OverviewDetailType.inverters:
                      return _buildInverterCard(context, inverters[index]);
                    case OverviewDetailType.batteries:
                      return _buildBatteryCard(batteries[index]);
                    case OverviewDetailType.dataloggers:
                      return _buildCollectorCard(context, collectors[index]);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppColors.textSecondary,
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_icon, size: 17, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantCard(BuildContext context, Station station) {
    final statusColor = station.isOnline
        ? AppColors.online
        : station.isAlarm
        ? AppColors.alarm
        : AppColors.offline;
    final plantType = _plantTypeLabel(station);
    return _baseCard(
      statusColor: statusColor,
      title: station.stationName,
      subtitle:
          '$plantType - ${station.addr?.isNotEmpty == true ? station.addr! : station.statusText}',
      primaryMetricLabel: 'Power',
      primaryMetricValue: station.powerDisplay,
      secondaryMetricLabel: 'Today',
      secondaryMetricValue: station.dayEnergyDisplay,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlantDetailScreen(station: station),
          ),
        );
      },
    );
  }

  Widget _buildInverterCard(BuildContext context, Inverter inverter) {
    final statusColor = inverter.isOnline
        ? AppColors.online
        : inverter.isAlarm
        ? AppColors.alarm
        : AppColors.offline;
    return _baseCard(
      statusColor: statusColor,
      title: inverter.inverterName ?? inverter.sn,
      subtitle: 'SN: ${inverter.sn}',
      primaryMetricLabel: 'Power',
      primaryMetricValue: inverter.pacDisplay,
      secondaryMetricLabel: 'Today',
      secondaryMetricValue: inverter.eTodayDisplay,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InverterDataScreen(inverter: inverter),
          ),
        );
      },
    );
  }

  Widget _buildBatteryCard(Battery battery) {
    final statusColor = battery.isOnline
        ? AppColors.online
        : battery.isAlarm
        ? AppColors.alarm
        : AppColors.offline;
    return _baseCard(
      statusColor: statusColor,
      title: battery.batteryName ?? battery.sn,
      subtitle: 'SN: ${battery.sn}',
      primaryMetricLabel: 'SOC',
      primaryMetricValue: battery.socDisplay,
      secondaryMetricLabel: 'Power',
      secondaryMetricValue:
          '${battery.batteryPower?.toStringAsFixed(1) ?? "0"} ${battery.batteryPowerStr ?? "W"}',
    );
  }

  Widget _buildCollectorCard(BuildContext context, Collector collector) {
    final statusColor = collector.isOnline
        ? AppColors.online
        : AppColors.offline;
    return _baseCard(
      statusColor: statusColor,
      title: collector.collectorName ?? collector.sn,
      subtitle: 'SN: ${collector.sn}',
      primaryMetricLabel: 'Status',
      primaryMetricValue: collector.statusText,
      secondaryMetricLabel: 'Inverterccs',
      secondaryMetricValue: '${collector.inverterCount ?? 0}',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CollectorDetailScreen(collector: collector),
          ),
        );
      },
    );
  }

  Widget _baseCard({
    required Color statusColor,
    required String title,
    required String subtitle,
    required String primaryMetricLabel,
    required String primaryMetricValue,
    required String secondaryMetricLabel,
    required String secondaryMetricValue,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: _cardDecoration,
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _metricText(primaryMetricLabel, primaryMetricValue),
                      const SizedBox(width: 16),
                      _metricText(secondaryMetricLabel, secondaryMetricValue),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 52, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Belum ada data $_title',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
