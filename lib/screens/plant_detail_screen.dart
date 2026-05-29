import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../models/station.dart';
import '../models/station_detail.dart';
import '../models/inverter.dart';
import '../models/collector.dart';
import '../models/alarm.dart';
import '../models/energy_data.dart';
import '../repositories/monitoring_repository.dart';
import '../widgets/energy_chart.dart';
import '../widgets/shimmer_loading.dart';
import 'inverter_data_screen.dart';

const _bg = AppColors.background;
const _surface = AppColors.surface;
const _border = AppColors.surfaceBorder;
const _textPrimary = AppColors.textPrimary;
const _textSecondary = AppColors.textSecondary;
const _textTertiary = AppColors.textTertiary;

enum _ChartTab { day, month, year, lifetime }

enum _BottomTab { overview, device, alarm, settings }

enum _DeviceFilter { all, inverter, datalogger }

class PlantDetailScreen extends StatefulWidget {
  final Station station;
  const PlantDetailScreen({super.key, required this.station});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final MonitoringRepository _repository = MonitoringRepository();

  // data
  StationDetail? _detail;
  List<Inverter> _inverters = [];
  List<Collector> _collectors = [];
  List<Alarm> _alarms = [];
  List<EnergyData> _chartData = [];

  // loading flags
  bool _loadingDetail = true;
  bool _loadingInverters = true;
  bool _loadingCollectors = true;
  bool _loadingAlarms = true;
  bool _loadingChart = true;

  // tab state
  _BottomTab _bottomTab = _BottomTab.overview;
  _DeviceFilter _deviceFilter = _DeviceFilter.all;

  // chart state
  _ChartTab _chartTab = _ChartTab.day;
  bool _showPower = true;
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedYear = DateTime.now();

  // ─── Init ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadInverters();
    _loadCollectors();
    _loadAlarms();
    _loadChart();
  }

  // ─── Loaders ──────────────────────────────────────────────────────

  Future<void> _refresh() async {
    await Future.wait([
      _loadDetail(),
      _loadInverters(),
      _loadCollectors(),
      _loadAlarms(),
      _loadChart(),
    ]);
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final d = await _repository.getPlantDetail(
        widget.station.id,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _detail = d;
          _loadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _loadInverters() async {
    setState(() => _loadingInverters = true);
    try {
      final inv = await _repository.getInverters(
        stationId: widget.station.id,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _inverters = inv;
          _loadingInverters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInverters = false);
    }
  }

  Future<void> _loadCollectors() async {
    setState(() => _loadingCollectors = true);
    try {
      final cols = await _repository.getCollectors(
        stationId: widget.station.id,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _collectors = cols;
          _loadingCollectors = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCollectors = false);
    }
  }

  Future<void> _loadAlarms() async {
    setState(() => _loadingAlarms = true);
    try {
      final alarms = await _repository.getAlarms(
        stationId: widget.station.id,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _alarms = alarms;
          _loadingAlarms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAlarms = false);
    }
  }

  Future<void> _loadChart() async {
    setState(() => _loadingChart = true);
    try {
      List<EnergyData> data;
      switch (_chartTab) {
        case _ChartTab.day:
          data = await _repository.getStationDayEnergy(
            stationId: widget.station.id,
            date: DateFormat('yyyy-MM-dd').format(_selectedDay),
            forceRefresh: true,
          );
          break;
        case _ChartTab.month:
          data = await _repository.getStationMonthEnergy(
            stationId: widget.station.id,
            month: DateFormat('yyyy-MM').format(_selectedMonth),
            forceRefresh: true,
          );
          break;
        case _ChartTab.year:
          data = await _repository.getStationYearEnergy(
            stationId: widget.station.id,
            year: DateFormat('yyyy').format(_selectedYear),
            forceRefresh: true,
          );
          break;
        case _ChartTab.lifetime:
          data = await _repository.getStationYearEnergy(
            stationId: widget.station.id,
            year: DateFormat('yyyy').format(DateTime.now()),
            forceRefresh: true,
          );
          break;
      }
      if (mounted) {
        setState(() {
          _chartData = data;
          _loadingChart = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingChart = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String _currentPlantTypeLabel() {
    final batteryCount = _inverters
        .where(
          (inv) =>
              (inv.batteryCapacitySoc ?? 0) > 0.01 ||
              (inv.batteryPower?.abs() ?? 0) > 0.001,
        )
        .length;
    return widget.station.plantTypeLabel(
      inverterModelHints: _inverters.expand<String?>(
        (i) => [i.productModel, i.inverterName],
      ),
      batteryDeviceCount: batteryCount,
      batteryPercent: _detail?.batteryPercent,
      batteryPower: _detail?.batteryPower,
      gridPurchasedDayEnergy: _detail?.gridPurchasedDayEnergy,
      gridSellDayEnergy: _detail?.gridSellDayEnergy,
      homeLoadTodayEnergy: _detail?.homeLoadTodayEnergy,
    );
  }

  String _formattedUpdateTime() {
    final ts = _detail?.dataTimestamp;
    if (ts != null) {
      final ms = int.tryParse(ts.trim());
      if (ms != null && ms > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        return '${DateFormat('dd/MM/yyyy HH:mm:ss').format(dt)} (UTC+07:00)';
      }
      if (ts.trim().isNotEmpty) return ts;
    }
    return widget.station.formattedUpdateTime;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                backgroundColor: _surface,
                child: _buildTabContent(),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final s = widget.station;
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: _textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.stationName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID:${s.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusDot(s.isOnline),
        ],
      ),
    );
  }

  Widget _statusDot(bool online) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: online ? AppColors.online : AppColors.offline,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          online ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: online ? AppColors.online : AppColors.offline,
          ),
        ),
      ],
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _navItem(_BottomTab.overview, 'Overview', Icons.dashboard_rounded),
          _navItem(_BottomTab.device, 'Device', Icons.developer_board_rounded),
          _navItem(_BottomTab.alarm, 'Alarm', Icons.notifications_rounded),
          _navItem(_BottomTab.settings, 'Settings', Icons.settings_rounded),
        ],
      ),
    );
  }

  Widget _navItem(_BottomTab tab, String label, IconData icon) {
    final selected = _bottomTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _bottomTab = tab),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _textTertiary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab content router ─────────────────────────────────────────

  Widget _buildTabContent() {
    switch (_bottomTab) {
      case _BottomTab.overview:
        return _buildOverviewTab();
      case _BottomTab.device:
        return _buildDeviceTab();
      case _BottomTab.alarm:
        return _buildAlarmTab();
      case _BottomTab.settings:
        return _buildSettingsTab();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeroSection()),
        SliverToBoxAdapter(child: _buildUpdateBar()),
        SliverToBoxAdapter(child: _buildDailyDataSection()),
        SliverToBoxAdapter(child: _buildChartSection()),
        SliverToBoxAdapter(child: _buildWeatherSection()),
        SliverToBoxAdapter(child: _buildEnvironmentSection()),
        SliverToBoxAdapter(child: _buildApiDataSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    final d = _detail;
    final s = widget.station;
    final pvPower = d?.inverterPower ?? d?.power ?? s.power ?? 0;
    final pvUnit = d?.inverterPowerStr ?? d?.powerStr ?? s.powerStr ?? 'kW';
    final gridPow = d?.psum ?? 0;
    final gridUnit = d?.psumStr ?? 'kW';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        children: [
          _plantTypeBadge(_currentPlantTypeLabel()),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFF7ED),
                        AppColors.primary.withValues(alpha: 0.08),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/inverter_product.png',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _powerBubble(
                    'PV',
                    pvPower.toStringAsFixed(2),
                    pvUnit,
                    AppColors.primary,
                    Icons.solar_power_rounded,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _powerBubble(
                    'Grid',
                    gridPow.toStringAsFixed(2),
                    gridUnit,
                    const Color(0xFF0F766E),
                    Icons.public_rounded,
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: _powerBubble(
                    'Load',
                    (d?.familyLoadPower ?? 0).toStringAsFixed(2),
                    d?.familyLoadPowerStr ?? 'kW',
                    const Color(0xFF1D4ED8),
                    Icons.electrical_services_rounded,
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _powerBubble(
                    'Battery',
                    (d?.batteryPower ?? 0).toStringAsFixed(2),
                    d?.batteryPowerStr ?? 'kW',
                    const Color(0xFF7C3AED),
                    Icons.battery_charging_full_rounded,
                  ),
                ),
              ],
            ),
          ),
          if (widget.station.addr != null &&
              widget.station.addr!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.station.addr!,
              style: const TextStyle(fontSize: 11, color: _textTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _powerBubble(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _textTertiary,
                ),
              ),
              Text(
                '$value $unit',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _plantTypeBadge(String label) {
    Color text, bg;
    switch (label) {
      case 'Hybrid':
        text = const Color(0xFF9A3412);
        bg = const Color(0xFFFFEDD5);
        break;
      case 'Off Grid':
        text = const Color(0xFF1D4ED8);
        bg = const Color(0xFFDBEAFE);
        break;
      default:
        text = const Color(0xFF166534);
        bg = const Color(0xFFDCFCE7);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  // ── Update bar ───────────────────────────────────────────────────

  Widget _buildUpdateBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, size: 12, color: _textTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Last Update: ${_formattedUpdateTime()}',
              style: const TextStyle(
                fontSize: 10,
                color: _textTertiary,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Daily Data ───────────────────────────────────────────────────

  Widget _buildDailyDataSection() {
    if (_loadingDetail) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: ShimmerLoading(height: 220, borderRadius: 16),
      );
    }

    final d = _detail;
    final s = widget.station;
    final dayKwh = d?.dayEnergy ?? s.dayEnergy ?? 0;
    final dayUnit = d?.dayEnergyStr ?? s.dayEnergyStr ?? 'kWh';
    final monthKwh = d?.monthEnergy ?? s.monthEnergy ?? 0;
    final monthUnit = d?.monthEnergyStr ?? s.monthEnergyStr ?? 'kWh';
    final totalKwh = d?.allEnergy ?? s.allEnergy ?? 0;
    final totalUnit = d?.allEnergyStr ?? s.allEnergyStr ?? 'kWh';
    final dayInc = d?.dayIncomeDisplay ?? '-';
    final monInc = d?.monthIncomeDisplay ?? '-';
    final totInc = d?.allIncomeDisplay ?? '-';
    final yrKwh = d?.yearEnergy ?? s.yearEnergy ?? 0;
    final yrUnit = d?.yearEnergyStr ?? s.yearEnergyStr ?? 'kWh';
    final yrInc = d?.yearIncomeDisplay ?? '-';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _bigStatCard(
                  title: 'Daily Yield',
                  value: dayKwh.toStringAsFixed(1),
                  unit: dayUnit,
                  icon: Icons.wb_sunny_outlined,
                  tint: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _bigStatCard(
                  title: 'Daily Earning',
                  value: dayInc,
                  unit: '',
                  icon: Icons.payments_outlined,
                  tint: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _statCell(
                      'Daily Yield',
                      '${dayKwh.toStringAsFixed(1)} $dayUnit',
                    ),
                    _divV(),
                    _statCell(
                      'Monthly Yield',
                      '${monthKwh.toStringAsFixed(1)} $monthUnit',
                    ),
                    _divV(),
                    _statCell(
                      'Total Yield',
                      '${totalKwh.toStringAsFixed(1)} $totalUnit',
                    ),
                  ],
                ),
                const Divider(height: 18, thickness: 0.5),
                Row(
                  children: [
                    _statCell('Daily Earning', '≈$dayInc'),
                    _divV(),
                    _statCell('Monthly Earning', '≈$monInc'),
                    _divV(),
                    _statCell('Total Earning', '≈$totInc'),
                  ],
                ),
              ],
            ),
          ),
          if (yrKwh > 0 || yrInc != '-') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  _statCell(
                    'Year Yield',
                    '${yrKwh.toStringAsFixed(1)} $yrUnit',
                  ),
                  _divV(),
                  _statCell('Year Earning', '≈$yrInc'),
                  _divV(),
                  _statCell(
                    'Full Load Hours',
                    '${(_detail?.fullHour ?? 0).toStringAsFixed(2)} h',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: tint),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            unit.isEmpty ? value : '$value $unit',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divV() => Container(width: 0.5, height: 32, color: _border);

  // ── Chart ────────────────────────────────────────────────────────

  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chartTabPill(_ChartTab.day, 'Day'),
              const SizedBox(width: 6),
              _chartTabPill(_ChartTab.month, 'Month'),
              const SizedBox(width: 6),
              _chartTabPill(_ChartTab.year, 'Year'),
              const SizedBox(width: 6),
              _chartTabPill(_ChartTab.lifetime, 'Lifetime'),
              const Spacer(),
              if (_chartTab == _ChartTab.day) _powerEnergyToggle(),
            ],
          ),
          const SizedBox(height: 10),
          if (_chartTab != _ChartTab.lifetime) _buildDateNavigator(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: _loadingChart
                ? const ShimmerLoading(height: 200, borderRadius: 10)
                : _chartData.isEmpty
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No chart data',
                        style: TextStyle(color: _textTertiary, fontSize: 12),
                      ),
                    ),
                  )
                : EnergyChart(
                    dataPoints: _chartData,
                    title: _chartTab == _ChartTab.day
                        ? (_showPower ? 'Power (kW)' : 'Energy (kWh)')
                        : 'Energy (kWh)',
                    showPower: _chartTab == _ChartTab.day && _showPower,
                  ),
          ),
          const SizedBox(height: 10),
          _buildChartSummaryRow(),
        ],
      ),
    );
  }

  Widget _chartTabPill(_ChartTab tab, String label) {
    final selected = _chartTab == tab;
    return GestureDetector(
      onTap: () {
        if (_chartTab == tab) return;
        setState(() => _chartTab = tab);
        _loadChart();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.primary : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _powerEnergyToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _togglePill(
            'Power',
            _showPower,
            () => setState(() => _showPower = true),
          ),
          _togglePill(
            'Energy',
            !_showPower,
            () => setState(() => _showPower = false),
          ),
        ],
      ),
    );
  }

  Widget _togglePill(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEDD5) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF9A3412) : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigator() {
    final now = DateTime.now();
    final isMax =
        (_chartTab == _ChartTab.day && _isSameDay(_selectedDay, now)) ||
        (_chartTab == _ChartTab.month &&
            _selectedMonth.year == now.year &&
            _selectedMonth.month == now.month) ||
        (_chartTab == _ChartTab.year && _selectedYear.year == now.year);

    String label;
    switch (_chartTab) {
      case _ChartTab.day:
        label = DateFormat('dd/MM/yyyy').format(_selectedDay);
        break;
      case _ChartTab.month:
        label = DateFormat('MM/yyyy').format(_selectedMonth);
        break;
      case _ChartTab.year:
        label = DateFormat('yyyy').format(_selectedYear);
        break;
      default:
        label = '';
    }

    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              switch (_chartTab) {
                case _ChartTab.day:
                  _selectedDay = _selectedDay.subtract(const Duration(days: 1));
                  break;
                case _ChartTab.month:
                  _selectedMonth = DateTime(
                    _selectedMonth.year,
                    _selectedMonth.month - 1,
                  );
                  break;
                case _ChartTab.year:
                  _selectedYear = DateTime(_selectedYear.year - 1);
                  break;
                default:
                  break;
              }
            });
            _loadChart();
          },
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: _textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: isMax
              ? null
              : () {
                  setState(() {
                    switch (_chartTab) {
                      case _ChartTab.day:
                        _selectedDay = _selectedDay.add(
                          const Duration(days: 1),
                        );
                        break;
                      case _ChartTab.month:
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month + 1,
                        );
                        break;
                      case _ChartTab.year:
                        _selectedYear = DateTime(_selectedYear.year + 1);
                        break;
                      default:
                        break;
                    }
                  });
                  _loadChart();
                },
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: isMax ? _border : _textSecondary,
        ),
      ],
    );
  }

  Widget _buildChartSummaryRow() {
    final d = _detail;
    final s = widget.station;
    double yieldVal;
    String yieldUnit;
    double earning;
    String earningUnit;
    double fullHour;

    switch (_chartTab) {
      case _ChartTab.day:
        yieldVal = d?.dayEnergy ?? s.dayEnergy ?? 0;
        yieldUnit = d?.dayEnergyStr ?? s.dayEnergyStr ?? 'kWh';
        earning = d?.dayInCome ?? 0;
        earningUnit = d?.dayInComeUnit ?? '';
        fullHour = d?.fullHour ?? 0;
        break;
      case _ChartTab.month:
        yieldVal = d?.monthEnergy ?? s.monthEnergy ?? 0;
        yieldUnit = d?.monthEnergyStr ?? s.monthEnergyStr ?? 'kWh';
        earning = d?.monthInCome ?? 0;
        earningUnit = d?.monthInComeUnit ?? '';
        fullHour = 0;
        break;
      case _ChartTab.year:
        yieldVal = d?.yearEnergy ?? s.yearEnergy ?? 0;
        yieldUnit = d?.yearEnergyStr ?? s.yearEnergyStr ?? 'kWh';
        earning = d?.yearInCome ?? 0;
        earningUnit = d?.yearInComeUnit ?? '';
        fullHour = 0;
        break;
      case _ChartTab.lifetime:
        yieldVal = d?.allEnergy ?? s.allEnergy ?? 0;
        yieldUnit = d?.allEnergyStr ?? s.allEnergyStr ?? 'kWh';
        earning = d?.allInCome ?? 0;
        earningUnit = d?.allInComeUnit ?? '';
        fullHour = 0;
        break;
    }

    String fmtInc(double v, String u) {
      String str;
      if (v.abs() >= 1000000) {
        str = '${(v / 1000000).toStringAsFixed(3)}M';
      } else if (v.abs() >= 1000) {
        str = '${(v / 1000).toStringAsFixed(3)}k';
      } else {
        str = v.toStringAsFixed(2);
      }
      return u.isNotEmpty ? '$str $u' : str;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _statCell('Yield', '${yieldVal.toStringAsFixed(1)} $yieldUnit'),
          _divV(),
          _statCell('Earning', fmtInc(earning, earningUnit)),
          if (fullHour > 0) ...[
            _divV(),
            _statCell('Full Load Hours', '${fullHour.toStringAsFixed(2)} h'),
          ],
        ],
      ),
    );
  }

  // ── Weather ──────────────────────────────────────────────────────

  Widget _buildWeatherSection() {
    if (_loadingDetail) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: ShimmerLoading(height: 130, borderRadius: 16),
      );
    }
    final d = _detail;
    final temp =
        (d?.tmpMin?.isNotEmpty == true && d?.tmpMax?.isNotEmpty == true)
        ? '${d!.tmpMin}~${d.tmpMax} ${d.tmpUnit ?? ""}'.trim()
        : (d?.tmpMax?.isNotEmpty == true
              ? '${d!.tmpMax} ${d.tmpUnit ?? ""}'.trim()
              : '-');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _weatherCell('Temp', temp, Icons.thermostat_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _weatherCell(
                    'Sunrise/Sunset',
                    d?.sunriseSunsetDisplay ?? '-',
                    Icons.wb_twilight_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _weatherCell(
                    'Wind',
                    d?.windDisplay ?? '-',
                    Icons.air_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _weatherCell(
                    'Humidity',
                    d?.humidity != null ? '${d!.humidity}%' : '-',
                    Icons.water_drop_rounded,
                  ),
                ),
              ],
            ),
            if (d?.condTxtD?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _weatherCell('Condition', d!.condTxtD!, Icons.cloud_rounded),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weatherCell(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Environment ──────────────────────────────────────────────────

  Widget _buildEnvironmentSection() {
    if (_loadingDetail) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: ShimmerLoading(height: 120, borderRadius: 16),
      );
    }
    final d = _detail;
    final s = widget.station;
    final totalKwh = d?.allEnergy ?? s.allEnergy ?? 0;
    final co2 = d?.co2Reduce ?? (totalKwh * 0.7);
    final coal = d?.coalReduction ?? (totalKwh * 0.4);
    final trees = d?.treeNum ?? (co2 / 21.77);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Environmental Benefits',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _benefitCard(
                  Icons.park_rounded,
                  trees.isFinite ? trees.toStringAsFixed(3) : '-',
                  'Equivalent\nTrees Planted',
                  const Color(0xFF166534),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _benefitCard(
                  Icons.eco_rounded,
                  '${co2.isFinite ? co2.toStringAsFixed(3) : "-"} kg',
                  'CO₂\nReduction',
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _benefitCard(
                  Icons.local_fire_department_rounded,
                  '${coal.isFinite ? coal.toStringAsFixed(3) : "-"} kg',
                  'Standard Coal\nSaved',
                  const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            d?.co2Reduce != null
                ? 'Data from API.'
                : 'Estimated from total energy.',
            style: const TextStyle(fontSize: 10, color: _textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _benefitCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _textTertiary,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ── Raw API data ─────────────────────────────────────────────────

  Widget _buildApiDataSection() {
    if (_loadingDetail || _detail == null) return const SizedBox.shrink();
    final pretty = const JsonEncoder.withIndent('  ').convert(_detail!.raw);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: ExpansionTile(
          title: const Text(
            'Raw API Data (stationDetail)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          subtitle: Text(
            '${_detail!.raw.length} keys',
            style: const TextStyle(
              fontSize: 11,
              color: _textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: SelectableText(
                  pretty,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DEVICE TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDeviceTab() {
    final List<_DeviceItem> all = [
      ..._inverters.map(
        (inv) => _DeviceItem(
          type: _DeviceFilter.inverter,
          name: inv.inverterName ?? 'Inverter',
          sn: inv.sn,
          isOnline: inv.isOnline,
          isAlarm: inv.isAlarm,
          subtitle: inv.pacDisplay,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InverterDataScreen(inverter: inv),
            ),
          ),
        ),
      ),
      ..._collectors.map(
        (col) => _DeviceItem(
          type: _DeviceFilter.datalogger,
          name: col.collectorName ?? 'Datalogger',
          sn: col.sn,
          isOnline: col.isOnline,
          isAlarm: false,
          subtitle: col.firmwareVersion != null
              ? 'FW: ${col.firmwareVersion}'
              : '',
          onTap: null,
        ),
      ),
    ];

    final filtered = _deviceFilter == _DeviceFilter.all
        ? all
        : all.where((d) => d.type == _deviceFilter).toList();

    final loading = _loadingInverters || _loadingCollectors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              _filterChip(_DeviceFilter.all, 'All'),
              const SizedBox(width: 8),
              _filterChip(_DeviceFilter.inverter, 'Inverter'),
              const SizedBox(width: 8),
              _filterChip(_DeviceFilter.datalogger, 'Datalogger'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Grid
        Expanded(
          child: loading
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: 4,
                    itemBuilder: (context, i) =>
                        const ShimmerLoading(height: 0, borderRadius: 16),
                  ),
                )
              : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.devices_other_rounded,
                        size: 48,
                        color: _border,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No devices',
                        style: TextStyle(color: _textTertiary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildDeviceCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(_DeviceFilter filter, String label) {
    final selected = _deviceFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _deviceFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.primary : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(_DeviceItem item) {
    final statusColor = item.isAlarm
        ? AppColors.alarm
        : item.isOnline
        ? AppColors.online
        : AppColors.offline;
    final isInverter = item.type == _DeviceFilter.inverter;

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        isInverter
                            ? 'assets/images/inverter_product.png'
                            : 'assets/images/datalogger_product.png',
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Icon(
                          isInverter
                              ? Icons.memory_rounded
                              : Icons.router_rounded,
                          size: 64,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SN:${item.sn}',
                    style: const TextStyle(fontSize: 10, color: _textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ALARM TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAlarmTab() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          sliver: _loadingAlarms
              ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerLoading(height: 72, borderRadius: 12),
                    ),
                    childCount: 4,
                  ),
                )
              : _alarms.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_rounded,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No alarms',
                          style: TextStyle(color: _textTertiary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildAlarmCard(_alarms[i]),
                    childCount: _alarms.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAlarmCard(Alarm alarm) {
    Color levelColor;
    IconData levelIcon;
    switch (alarm.alarmLevel) {
      case 3:
        levelColor = const Color(0xFF991B1B);
        levelIcon = Icons.error_rounded;
        break;
      case 2:
        levelColor = const Color(0xFFB45309);
        levelIcon = Icons.warning_rounded;
        break;
      default:
        levelColor = const Color(0xFF1D4ED8);
        levelIcon = Icons.info_rounded;
    }
    final recovered = alarm.isRecovered;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: levelColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(levelIcon, size: 18, color: levelColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.alarmName ?? alarm.alarmMsg ?? 'Unknown alarm',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  'SN: ${alarm.alarmDeviceSn}',
                  style: const TextStyle(fontSize: 10, color: _textTertiary),
                ),
                if (alarm.alarmBeginTimeStr != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Since: ${alarm.alarmBeginTimeStr}',
                    style: const TextStyle(fontSize: 10, color: _textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  alarm.levelText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: levelColor,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: recovered
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  recovered ? 'Resolved' : 'Active',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: recovered
                        ? const Color(0xFF166534)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SETTINGS TAB
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSettingsTab() {
    final s = widget.station;
    final d = _detail;

    final rows = <_SettingRow>[
      _SettingRow('Station Name', s.stationName),
      _SettingRow('Station ID', s.id),
      if (s.addr != null && s.addr!.isNotEmpty) _SettingRow('Address', s.addr!),
      _SettingRow('Status', s.isOnline ? 'Online' : 'Offline'),
      _SettingRow('Plant Type', _currentPlantTypeLabel()),
      if (d?.capacity != null)
        _SettingRow(
          'Capacity',
          '${d!.capacity!.toStringAsFixed(2)} ${d.capacityStr ?? "kWp"}',
        ),
      if (d?.inverterCount != null)
        _SettingRow('Inverters', '${d!.inverterCount}'),
      _SettingRow('Dataloggers', '${_collectors.length}'),
      if (d?.fullHour != null)
        _SettingRow('Full Load Hours', '${d!.fullHour!.toStringAsFixed(2)} h'),
      _SettingRow('Last Update', _formattedUpdateTime()),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (context, i) => const SizedBox(height: 1),
      itemBuilder: (_, i) {
        final row = rows[i];
        final isFirst = i == 0;
        final isLast = i == rows.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(16) : Radius.zero,
              bottom: isLast ? const Radius.circular(16) : Radius.zero,
            ),
          ),
          child: Row(
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  row.value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}

// ─── Helper data classes ───────────────────────────────────────────

class _DeviceItem {
  final _DeviceFilter type;
  final String name;
  final String sn;
  final bool isOnline;
  final bool isAlarm;
  final String subtitle;
  final VoidCallback? onTap;
  const _DeviceItem({
    required this.type,
    required this.name,
    required this.sn,
    required this.isOnline,
    required this.isAlarm,
    required this.subtitle,
    required this.onTap,
  });
}

class _SettingRow {
  final String label;
  final String value;
  const _SettingRow(this.label, this.value);
}
