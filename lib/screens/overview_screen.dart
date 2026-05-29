import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/battery.dart';
import '../models/collector.dart';
import '../models/inverter.dart';
import '../models/station.dart';
import '../repositories/monitoring_repository.dart';
import '../widgets/shimmer_loading.dart';
import 'overview_detail_screen.dart';
import 'plant_detail_screen.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with SingleTickerProviderStateMixin {
  final MonitoringRepository _repository = MonitoringRepository();
  late final AnimationController _revealController;

  List<Station> _stations = [];
  List<Inverter> _inverters = [];
  List<Battery> _batteries = [];
  List<Collector> _collectors = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _revealController
        ..stop()
        ..reset();
    }

    try {
      final overview = await _repository.getOverview(forceRefresh: true);

      if (!mounted) return;
      setState(() {
        _stations = overview.plants;
        _inverters = overview.inverters;
        _batteries = overview.batteries;
        _collectors = overview.collectors;
        _isLoading = false;
      });
      _revealController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _onlinePlants => _stations.where((s) => s.isOnline).length;
  int get _alarmPlants => _stations.where((s) => s.isAlarm).length;
  int get _offlinePlants =>
      _stations.where((s) => !s.isOnline && !s.isAlarm).length;
  int get _onlineInverters => _inverters.where((i) => i.isOnline).length;
  int get _onlineBatteries => _batteries.where((b) => b.isOnline).length;
  int get _onlineCollectors => _collectors.where((c) => c.isOnline).length;

  double get _totalCapacity =>
      _stations.fold(0.0, (sum, station) => sum + station.capacity);
  double get _totalPower =>
      _stations.fold(0.0, (sum, station) => sum + (station.power ?? 0));
  double get _todayEnergy =>
      _stations.fold(0.0, (sum, station) => sum + (station.dayEnergy ?? 0));
  double get _totalEnergy =>
      _stations.fold(0.0, (sum, station) => sum + (station.allEnergy ?? 0));

  double? get _averageBatterySoc {
    final values = _batteries
        .map((b) => b.batteryCapacitySoc)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    final total = values.fold(0.0, (sum, value) => sum + value);
    return total / values.length;
  }

  List<Station> get _topPlants {
    final items = [..._stations];
    items.sort((a, b) => (b.dayEnergy ?? 0).compareTo(a.dayEnergy ?? 0));
    return items.take(5).toList();
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

  Iterable<Inverter> _invertersForStation(Station station) {
    return _inverters.where(
      (inv) => _isSameStation(
        station: station,
        deviceStationId: inv.stationId,
        deviceStationName: inv.stationName,
      ),
    );
  }

  Iterable<Battery> _batteriesForStation(Station station) {
    return _batteries.where(
      (battery) => _isSameStation(
        station: station,
        deviceStationId: battery.stationId,
        deviceStationName: battery.stationName,
      ),
    );
  }

  String _plantTypeLabel(Station station) {
    final hints = _invertersForStation(
      station,
    ).expand<String?>((inv) => [inv.productModel, inv.inverterName]);
    final stationBatteries = _batteriesForStation(station).toList();
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
    gradient: AppColors.cardGradient,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.surfaceBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.02),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadOverview,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_isLoading)
              SliverToBoxAdapter(child: _buildLoadingSkeleton())
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(),
              )
            else ...[
              SliverToBoxAdapter(child: _staggerReveal(0, _buildSummaryCard())),
              SliverToBoxAdapter(child: _staggerReveal(1, _buildQuickStats())),
              SliverToBoxAdapter(child: _staggerReveal(2, _buildFleetStatus())),
              SliverToBoxAdapter(
                child: _staggerReveal(3, _buildPlantsSection()),
              ),
              SliverToBoxAdapter(
                child: _staggerReveal(4, _buildDevicesSection()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _staggerReveal(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.85);
    final end = (start + 0.28).clamp(start + 0.05, 1.0);
    final animation = CurvedAnimation(
      parent: _revealController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, animatedChild) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: animatedChild,
          ),
        );
      },
    );
  }

  void _openPlantsDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OverviewDetailScreen.plants(
          stations: _stations,
          inverters: _inverters,
          batteries: _batteries,
        ),
      ),
    );
  }

  void _openInvertersDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OverviewDetailScreen.inverters(inverters: _inverters),
      ),
    );
  }

  void _openBatteriesDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OverviewDetailScreen.batteries(batteries: _batteries),
      ),
    );
  }

  void _openCollectorsDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OverviewDetailScreen.dataloggers(collectors: _collectors),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.primaryLight.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ringkasan performa plant dan perangkat',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _loadOverview,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFEDD5),
              AppColors.primary.withValues(alpha: 0.18),
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$_onlinePlants online',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9A3412),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                '${_todayEnergy.toStringAsFixed(1)} kWh',
                key: ValueKey(_todayEnergy.toStringAsFixed(1)),
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_stations.length} plants  |  ${_totalCapacity.toStringAsFixed(1)} kWp installed  |  ${_totalPower.toStringAsFixed(1)} kW live',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _summaryMetric(
                    label: 'Installed',
                    value: '${_totalCapacity.toStringAsFixed(1)} kWp',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _summaryMetric(
                    label: 'Lifetime',
                    value: '${_totalEnergy.toStringAsFixed(1)} kWh',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildOverviewBars()),
                const SizedBox(width: 12),
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/inverter_product.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewBars() {
    final values = _topPlants
        .take(6)
        .map((s) => (s.dayEnergy ?? 0).clamp(0, double.infinity))
        .toList();
    if (values.isEmpty) {
      values.addAll([2.5, 4.2, 6.1, 5.0, 7.4, 6.6]);
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 112,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const topSlot = 26.0;
          const bottomGap = 6.0;
          const bottomLabel = 12.0;
          final barMax =
              (constraints.maxHeight - topSlot - bottomGap - bottomLabel).clamp(
                26.0,
                96.0,
              );
          const barMin = 18.0;
          final barRange = (barMax - barMin).clamp(0.0, 96.0);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (index) {
              final value = values[index];
              final selected = index == values.length - 2;
              final h = maxValue <= 0
                  ? barMin
                  : barMin + (value / maxValue) * barRange;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: topSlot,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: selected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${value.toStringAsFixed(0)} kWh',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryDark
                              : AppColors.primary.withValues(alpha: 0.26),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      const SizedBox(height: bottomGap),
                      SizedBox(
                        height: bottomLabel,
                        child: Center(
                          child: Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _summaryMetric({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9A3412)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _statCard(
            title: 'Plant Online',
            value: '$_onlinePlants',
            subtitle: '$_offlinePlants offline, $_alarmPlants alarm',
            icon: Icons.solar_power_rounded,
            color: AppColors.online,
            onTap: _openPlantsDetail,
          ),
          _statCard(
            title: 'Inverter Active',
            value: '$_onlineInverters/${_inverters.length}',
            subtitle: 'Tap untuk buka daftar inverter',
            icon: Icons.memory_rounded,
            color: AppColors.primary,
            onTap: _openInvertersDetail,
          ),
          _statCard(
            title: 'Battery Avg SOC',
            value: _averageBatterySoc != null
                ? '${_averageBatterySoc!.toStringAsFixed(0)}%'
                : '-',
            subtitle: '${_batteries.length} battery terdeteksi',
            icon: Icons.battery_charging_full_rounded,
            color: AppColors.warning,
            onTap: _openBatteriesDetail,
          ),
          _statCard(
            title: 'Lifetime Energy',
            value: '${_totalEnergy.toStringAsFixed(1)} kWh',
            subtitle: 'Akumulasi semua plant',
            icon: Icons.insights_rounded,
            color: AppColors.primaryDark,
            onTap: _openPlantsDetail,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final width = (MediaQuery.of(context).size.width - 42) / 2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFleetStatus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fleet health',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _statusRow(
              label: 'Plants',
              online: _onlinePlants,
              total: _stations.length,
              color: AppColors.online,
            ),
            const SizedBox(height: 12),
            _statusRow(
              label: 'Inverters',
              online: _onlineInverters,
              total: _inverters.length,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            _statusRow(
              label: 'Batteries',
              online: _onlineBatteries,
              total: _batteries.length,
              color: AppColors.warning,
            ),
            const SizedBox(height: 12),
            _statusRow(
              label: 'Dataloggers',
              online: _onlineCollectors,
              total: _collectors.length,
              color: AppColors.primaryDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow({
    required String label,
    required int online,
    required int total,
    required Color color,
  }) {
    final ratio = total == 0 ? 0.0 : online / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$online/$total online',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildPlantsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Top plants',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openPlantsDetail,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Plant dengan produksi harian tertinggi dan status terkini.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (_topPlants.isEmpty)
            _emptyPanel('Belum ada data plant untuk ditampilkan')
          else
            ..._topPlants.map(_buildPlantRow),
        ],
      ),
    );
  }

  Widget _buildPlantRow(Station station) {
    final statusColor = station.isOnline
        ? AppColors.online
        : station.isAlarm
        ? AppColors.alarm
        : AppColors.offline;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlantDetailScreen(station: station),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 5),
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
                    station.stationName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _plantTypeBadge(_plantTypeLabel(station)),
                  const SizedBox(height: 3),
                  Text(
                    station.addr?.isNotEmpty == true
                        ? station.addr!
                        : station.statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _plantMetric('Power', station.powerDisplay),
                      _plantMetric('Today', station.dayEnergyDisplay),
                      _plantMetric('Capacity', station.capacityDisplay),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _plantMetric(String label, String value) {
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

  Widget _plantTypeBadge(String label) {
    Color textColor;
    Color bgColor;

    switch (label) {
      case 'Hybrid':
        textColor = const Color(0xFF9A3412);
        bgColor = const Color(0xFFFFEDD5);
        break;
      case 'Off Grid':
        textColor = const Color(0xFF1D4ED8);
        bgColor = const Color(0xFFDBEAFE);
        break;
      default:
        textColor = const Color(0xFF166534);
        bgColor = const Color(0xFFDCFCE7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDevicesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _devicePanel(
            title: 'Inverters',
            total: _inverters.length,
            online: _onlineInverters,
            detail:
                '${_inverters.length - _onlineInverters} unit butuh perhatian',
            icon: Icons.memory_rounded,
            color: AppColors.primary,
            onTap: _openInvertersDetail,
          ),
          const SizedBox(height: 10),
          _devicePanel(
            title: 'Batteries',
            total: _batteries.length,
            online: _onlineBatteries,
            detail: _averageBatterySoc != null
                ? 'Rata-rata SOC ${_averageBatterySoc!.toStringAsFixed(0)}%'
                : 'Belum ada SOC yang terbaca',
            icon: Icons.battery_charging_full_rounded,
            color: AppColors.warning,
            onTap: _openBatteriesDetail,
          ),
          const SizedBox(height: 10),
          _devicePanel(
            title: 'Dataloggers',
            total: _collectors.length,
            online: _onlineCollectors,
            detail: '${_collectors.length - _onlineCollectors} logger offline',
            icon: Icons.router_rounded,
            color: AppColors.primaryDark,
            onTap: _openCollectorsDetail,
          ),
        ],
      ),
    );
  }

  Widget _devicePanel({
    required String title,
    required int total,
    required int online,
    required String detail,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$online/$total online',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
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

  Widget _buildLoadingSkeleton() {
    final cardWidth = (MediaQuery.of(context).size.width - 42) / 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          const ShimmerLoading(height: 172, borderRadius: 16),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              4,
              (_) => ShimmerLoading(
                width: cardWidth,
                height: 142,
                borderRadius: 16,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const ShimmerLoading(height: 160, borderRadius: 16),
          const SizedBox(height: 14),
          const ShimmerLoading(height: 24, borderRadius: 8),
          const SizedBox(height: 10),
          const ShimmerLoading(height: 84, borderRadius: 16),
          const SizedBox(height: 8),
          const ShimmerLoading(height: 84, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.alarm.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.alarm,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Overview belum bisa dimuat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOverview,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _emptyPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    _repository.dispose();
    super.dispose();
  }
}
