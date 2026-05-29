import 'dart:async';

import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/station.dart';
import '../models/inverter.dart';
import '../models/collector.dart';
import '../models/battery.dart';
import '../repositories/monitoring_repository.dart';
import '../widgets/shimmer_loading.dart';
import 'collector_detail_screen.dart';
import 'inverter_data_screen.dart';
import 'plant_detail_screen.dart';

class _DeviceMetricData {
  final String value;
  final String label;

  const _DeviceMetricData({required this.value, required this.label});
}

class _PlantReveal extends StatefulWidget {
  final int index;
  final bool enabled;
  final Widget child;

  const _PlantReveal({
    required this.index,
    required this.enabled,
    required this.child,
  });

  @override
  State<_PlantReveal> createState() => _PlantRevealState();
}

class _PlantRevealState extends State<_PlantReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _visible = true;
      return;
    }

    final delayMs = 60 + (widget.index.clamp(0, 10) * 45);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetOffset = widget.enabled ? const Offset(0, 0.06) : Offset.zero;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : targetOffset,
        child: widget.child,
      ),
    );
  }
}

const _dashboardBg = Color(0xFFF8FAFC);
const _dashboardSurface = Colors.white;
const _dashboardSurfaceSoft = Color(0xFFF1F5F9);
const _dashboardBorder = Color(0xFFE2E8F0);
const _dashboardBlueMuted = Color(0xFF9A3412); // orange text
const _textOnDark = Color(0xFF0F172A);
const _mutedOnDark = Color(0xFF64748B);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final MonitoringRepository _repository = MonitoringRepository();
  late TabController _tabController;

  // Plants
  List<Station> _stations = [];
  bool _isLoadingPlants = true;
  int _statusFilter = 0; // 0=All,1=Online,2=Alarm,3=Offline
  DateTime? _lastPlantRefresh;
  Timer? _plantsRealtimeTimer;
  bool _isRealtimeRefreshingPlants = false;
  bool _plantsEnterAnimatedOnce = false;

  // Inverters
  List<Inverter> _inverters = [];
  bool _isLoadingInverters = false;
  bool _invertersLoaded = false;

  // Battery
  List<Battery> _batteries = [];
  bool _isLoadingBatteries = false;
  bool _batteriesLoaded = false;

  // Datalogger
  List<Collector> _collectors = [];
  bool _isLoadingCollectors = false;
  bool _collectorsLoaded = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadDashboardOverview();
    _startPlantsRealtimeRefresh();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _plantsEnterAnimatedOnce = true);
    });
  }

  void _startPlantsRealtimeRefresh() {
    _plantsRealtimeTimer?.cancel();
    _plantsRealtimeTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) async {
      if (!mounted || _isRealtimeRefreshingPlants) return;
      _isRealtimeRefreshingPlants = true;
      try {
        await _loadStations(showLoading: false, silentError: true);
      } finally {
        _isRealtimeRefreshingPlants = false;
      }
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 1:
        if (!_invertersLoaded) _loadInverters();
        break;
      case 2:
        if (!_batteriesLoaded) _loadBatteries();
        break;
      case 3:
        if (!_collectorsLoaded) _loadCollectors();
        break;
    }
  }

  Future<void> _loadDashboardOverview() async {
    if (mounted) {
      setState(() {
        _isLoadingPlants = true;
        _isLoadingInverters = true;
        _isLoadingBatteries = true;
        _isLoadingCollectors = true;
        _errorMessage = null;
      });
    }

    try {
      final overview = await _repository.getOverview(forceRefresh: true);
      if (!mounted) return;

      setState(() {
        _stations = overview.plants;
        _inverters = overview.inverters;
        _batteries = overview.batteries;
        _collectors = overview.collectors;
        _isLoadingPlants = false;
        _isLoadingInverters = false;
        _isLoadingBatteries = false;
        _isLoadingCollectors = false;
        _invertersLoaded = true;
        _batteriesLoaded = true;
        _collectorsLoaded = true;
        _lastPlantRefresh = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoadingPlants = false;
        _isLoadingInverters = false;
        _isLoadingBatteries = false;
        _isLoadingCollectors = false;
        _invertersLoaded = true;
        _batteriesLoaded = true;
        _collectorsLoaded = true;
      });
    }
  }

  Future<void> _loadStations({
    bool showLoading = true,
    bool silentError = false,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingPlants = true;
        _errorMessage = null;
      });
    }
    try {
      final s = await _repository.getPlants(forceRefresh: showLoading);
      if (mounted) {
        setState(() {
          _stations = s;
          _isLoadingPlants = false;
          _lastPlantRefresh = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted && !silentError) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingPlants = false;
        });
      }
    }
  }

  Future<void> _loadInverters() async {
    setState(() => _isLoadingInverters = true);
    try {
      final inv = await _repository.getInverters();
      if (mounted) {
        setState(() {
          _inverters = inv;
          _isLoadingInverters = false;
          _invertersLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingInverters = false;
          _invertersLoaded = true;
        });
      }
    }
  }

  Future<void> _loadBatteries() async {
    setState(() => _isLoadingBatteries = true);
    try {
      final b = await _repository.getBatteries();
      if (mounted) {
        setState(() {
          _batteries = b;
          _isLoadingBatteries = false;
          _batteriesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBatteries = false;
          _batteriesLoaded = true;
        });
      }
    }
  }

  Future<void> _loadCollectors() async {
    setState(() => _isLoadingCollectors = true);
    try {
      final c = await _repository.getCollectors();
      if (mounted) {
        setState(() {
          _collectors = c;
          _isLoadingCollectors = false;
          _collectorsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCollectors = false;
          _collectorsLoaded = true;
        });
      }
    }
  }

  List<Station> get _filteredStations {
    switch (_statusFilter) {
      case 1:
        return _stations.where((s) => s.isOnline).toList();
      case 2:
        return _stations.where((s) => s.isAlarm).toList();
      case 3:
        return _stations.where((s) => !s.isOnline && !s.isAlarm).toList();
      default:
        return _stations;
    }
  }

  int get _onlineCount => _stations.where((s) => s.isOnline).length;
  int get _alarmCount => _stations.where((s) => s.isAlarm).length;
  int get _offlineCount => _stations.length - _onlineCount - _alarmCount;
  double get _todayEnergyTotal =>
      _stations.fold(0, (sum, s) => sum + (s.dayEnergy ?? 0));
  double get _installedCapacityTotal =>
      _stations.fold(0, (sum, s) => sum + s.capacity);

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

  List<Inverter> _invertersForStation(Station station) {
    return _inverters
        .where(
          (inv) => _isSameStation(
            station: station,
            deviceStationId: inv.stationId,
            deviceStationName: inv.stationName,
          ),
        )
        .toList();
  }

  List<Battery> _batteriesForStation(Station station) {
    return _batteries
        .where(
          (b) => _isSameStation(
            station: station,
            deviceStationId: b.stationId,
            deviceStationName: b.stationName,
          ),
        )
        .toList();
  }

  List<Collector> _collectorsForStation(Station station) {
    return _collectors
        .where(
          (c) => _isSameStation(
            station: station,
            deviceStationId: c.stationId,
            deviceStationName: c.stationName,
          ),
        )
        .toList();
  }

  String _plantTypeLabel(Station station) {
    final hints = _invertersForStation(
      station,
    ).expand<String?>((inv) => [inv.productModel, inv.inverterName]);
    final stationBatteries = _batteriesForStation(station);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashboardBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildGradientHeader(),
            _buildTopTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPlantsTab(),
                  _buildInvertersTab(),
                  _buildBatteryTab(),
                  _buildDataloggerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────

  Widget _buildGradientHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFF7ED)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 132,
                    height: 40,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/images/jarwinn_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _headerBtn(Icons.refresh_rounded, () {
                    _loadStations();
                    _invertersLoaded = false;
                    _batteriesLoaded = false;
                    _collectorsLoaded = false;
                    _onTabChanged();
                  }),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Plants',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _textOnDark,
                  height: 1.05,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_onlineCount plant online, ${_todayEnergyTotal.toStringAsFixed(1)} kWh generated today',
                style: const TextStyle(
                  fontSize: 13,
                  color: _mutedOnDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _dashboardBorder),
        ),
        child: Icon(icon, size: 20, color: AppColors.primaryDark),
      ),
    );
  }

  // ─── TOP TABS ─────────────────────────────────────────────

  Widget _buildTopTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _dashboardBorder),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: _mutedOnDark,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          padding: const EdgeInsets.all(6),
          tabs: const [
            Tab(text: 'Plants'),
            Tab(text: 'Inverter'),
            Tab(text: 'Battery'),
            Tab(text: 'Logger'),
          ],
        ),
      ),
    );
  }

  // ─── PLANTS TAB ───────────────────────────────────────────

  Widget _buildPlantsTab() {
    return RefreshIndicator(
      onRefresh: _loadStations,
      color: AppColors.primary,
      backgroundColor: _dashboardSurface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildPullDownHint()),
          SliverToBoxAdapter(child: _buildStatusTabs()),
          SliverToBoxAdapter(child: _buildPlantFilterBar()),
          _buildPlantList(),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      color: _dashboardBg,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          _statusTab(0, '${_stations.length}', 'Plants', AppColors.primary),
          _statusTab(1, '$_onlineCount', 'Online', AppColors.online),
          _statusTab(2, '$_alarmCount', 'Alarm', AppColors.alarm),
          _statusTab(3, '$_offlineCount', 'Offline', AppColors.offline),
        ],
      ),
    );
  }

  Widget _statusTab(int idx, String count, String label, Color color) {
    final sel = _statusFilter == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = idx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sel ? color.withValues(alpha: 0.30) : _dashboardBorder,
            ),
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: sel ? color : _textOnDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? color : _mutedOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantFilterBar() {
    return Container(
      color: _dashboardBg,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _filterChip('Overview', selected: true),
            const SizedBox(width: 8),
            _filterChip('Savings'),
            const SizedBox(width: 8),
            _filterChip('Consumption'),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.20),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.35)
              : _dashboardBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primaryDark : _textOnDark,
        ),
      ),
    );
  }

  Widget _buildPullDownHint() {
    final dt = _lastPlantRefresh ?? DateTime.now();
    final ts =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
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
                const Expanded(
                  child: Text(
                    'Today Energy',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7C2D12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
                '${_todayEnergyTotal.toStringAsFixed(2)} kWh',
                key: ValueKey(_todayEnergyTotal.toStringAsFixed(2)),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Last sync $ts  |  ${_installedCapacityTotal.toStringAsFixed(1)} kWp installed',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9A3412),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildHeroBars()),
                const SizedBox(width: 12),
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.36),
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

  Widget _buildHeroBars() {
    final source = _filteredStations.isNotEmpty ? _filteredStations : _stations;
    final values = source
        .take(6)
        .map((station) => (station.dayEnergy ?? 0).clamp(0, double.infinity))
        .toList();
    if (values.isEmpty) {
      values.addAll([2.5, 4.2, 6.1, 5.0, 7.4, 6.6]);
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 112,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const topSlot = 26.0; // reserved for the selected tooltip
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

  Widget _buildPlantList() {
    if (_isLoadingPlants) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, _) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ShimmerLoading(
                height: 172,
                borderRadius: 22,
                baseColor: _dashboardSurfaceSoft,
                highlightColor: Colors.white,
              ),
            ),
            childCount: 3,
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return SliverFillRemaining(child: _buildError(_errorMessage!));
    }
    final filtered = _filteredStations;
    if (filtered.isEmpty) {
      return SliverFillRemaining(child: _buildEmpty('No plants found'));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final station = filtered[i];
          final card = _buildModernPlantCard(
            station,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => PlantDetailScreen(station: station),
              ),
            ),
          );
          return _PlantReveal(
            index: i,
            enabled: !_plantsEnterAnimatedOnce,
            child: card,
          );
        }, childCount: filtered.length),
      ),
    );
  }

  Widget _buildModernPlantCard(Station station, {VoidCallback? onTap}) {
    final statusColor = station.isOnline
        ? AppColors.online
        : station.isAlarm
        ? AppColors.alarm
        : AppColors.offline;
    final statusIcon = station.isOnline
        ? Icons.check_circle_rounded
        : station.isAlarm
        ? Icons.error_rounded
        : Icons.offline_bolt_rounded;
    final statusText = station.isOnline
        ? 'Online'
        : station.isAlarm
        ? 'Alarm'
        : 'Offline';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _dashboardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _dashboardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              station.stationName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textOnDark,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  station.addr?.isNotEmpty == true ? station.addr! : '-',
                  style: const TextStyle(fontSize: 12, color: _mutedOnDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _plantTypeBadge(_plantTypeLabel(station)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _plantMetric(
                              value:
                                  '${station.dayEnergy?.toStringAsFixed(1) ?? "0"}kWh',
                              label: 'Daily Yield',
                            ),
                          ),
                          Expanded(
                            child: _plantMetric(
                              value:
                                  '${station.power?.toStringAsFixed(1) ?? "0"}kW',
                              label: 'Power',
                            ),
                          ),
                          Expanded(
                            child: _plantMetric(
                              value:
                                  '${station.capacity.toStringAsFixed(1)}kWp',
                              label: 'Capacity',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPlantThumbnail(),
                  ],
                ),
                const SizedBox(height: 10),
                _buildPlantDeviceDetails(station),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      station.isOnline
                          ? Icons.update_rounded
                          : Icons.sync_disabled_rounded,
                      size: 14,
                      color: _mutedOnDark,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${station.isOnline ? "Last update " : "Offline Time: "}${station.formattedUpdateTime}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _mutedOnDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'More',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _plantMetric({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textOnDark,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _mutedOnDark)),
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

  Widget _buildPlantThumbnail() {
    return Container(
      width: 98,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
              child: Image.asset(
                'assets/images/inverter_product.png',
                fit: BoxFit.contain,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'INV',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── INVERTER TAB ─────────────────────────────────────────

  Widget _buildPlantDeviceDetails(Station station) {
    final inverterList = _invertersForStation(station);
    final inverterTotal = inverterList.isNotEmpty
        ? inverterList.length
        : (station.inverterCount ?? 0);
    final inverterOnline = inverterList.isNotEmpty
        ? inverterList.where((inv) => inv.isOnline).length
        : (station.inverterOnlineCount ?? 0);
    final inverterLivePower = inverterList.fold<double>(
      0,
      (sum, inv) => sum + (inv.pac ?? 0),
    );
    final inverterDetail = inverterTotal > 0
        ? '$inverterOnline/$inverterTotal online'
        : 'No inverter';

    final batteryList = _batteriesForStation(station);
    final batteryTotal = batteryList.isNotEmpty
        ? batteryList.length
        : (station.epmCount ?? 0);
    final batteryOnline = batteryList.where((b) => b.isOnline).length;
    final batterySocValues = batteryList
        .map((b) => b.batteryCapacitySoc)
        .whereType<double>()
        .toList();
    final batterySocAvg = batterySocValues.isEmpty
        ? null
        : batterySocValues.reduce((a, b) => a + b) / batterySocValues.length;
    final batteryDetail = batteryTotal > 0
        ? '$batteryOnline/$batteryTotal online'
        : 'No battery';
    final batteryInfo = batterySocAvg != null
        ? 'SOC ${batterySocAvg.toStringAsFixed(0)}%'
        : 'SOC -';

    final collectorList = _collectorsForStation(station);
    final collectorTotal = collectorList.isNotEmpty
        ? collectorList.length
        : (station.collectorCount ?? 0);
    final collectorOnline = collectorList.where((c) => c.isOnline).length;
    final collectorDetail = collectorTotal > 0
        ? '$collectorOnline/$collectorTotal online'
        : 'No datalogger';
    final collectorInfo = collectorTotal > 0
        ? '${collectorTotal - collectorOnline} offline'
        : '-';

    return Row(
      children: [
        Expanded(
          child: _deviceInfoTile(
            icon: Icons.memory_rounded,
            iconColor: AppColors.primary,
            title: 'Inverter',
            detail: inverterDetail,
            extra: inverterList.isNotEmpty
                ? '${inverterLivePower.toStringAsFixed(1)} kW live'
                : '${station.power?.toStringAsFixed(1) ?? "0"} kW',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _deviceInfoTile(
            icon: Icons.battery_charging_full_rounded,
            iconColor: AppColors.warning,
            title: 'Battery',
            detail: batteryDetail,
            extra: batteryInfo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _deviceInfoTile(
            icon: Icons.router_rounded,
            iconColor: AppColors.primaryDark,
            title: 'Datalogger',
            detail: collectorDetail,
            extra: collectorInfo,
          ),
        ),
      ],
    );
  }

  Widget _deviceInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String detail,
    required String extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _dashboardSurfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dashboardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _textOnDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _dashboardBlueMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            extra,
            style: const TextStyle(fontSize: 10, color: _mutedOnDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInvertersTab() {
    if (_isLoadingInverters) return _buildLoading();
    if (_inverters.isEmpty) {
      return _buildEmpty(
        'No inverters found\nTap to load',
        onTap: _loadInverters,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInverters,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _inverters.length,
        itemBuilder: (_, i) => _buildInverterCard(_inverters[i]),
      ),
    );
  }

  Widget _buildInverterCard(Inverter inv) {
    final color = inv.isOnline
        ? AppColors.online
        : inv.isAlarm
        ? AppColors.alarm
        : AppColors.offline;
    return _buildDeviceCard(
      icon: Icons.memory_rounded,
      iconColor: color,
      title: inv.inverterName ?? inv.sn,
      subtitle: (inv.stationName?.isNotEmpty == true)
          ? '${inv.stationName} | SN: ${inv.sn}'
          : 'SN: ${inv.sn}',
      statusText: inv.statusText,
      statusColor: color,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => InverterDataScreen(inverter: inv)),
      ),
      metrics: [
        _DeviceMetricData(value: inv.pacDisplay, label: 'Power'),
        _DeviceMetricData(value: inv.eTodayDisplay, label: 'Today'),
        _DeviceMetricData(value: inv.eTotalDisplay, label: 'Total'),
      ],
      timeText: _formatDeviceTime(inv.dataTimestamp, inv.dataTimestampStr),
    );
  }

  // ─── BATTERY TAB ──────────────────────────────────────────

  Widget _buildBatteryTab() {
    if (_isLoadingBatteries) return _buildLoading();
    if (_batteries.isEmpty) {
      return _buildEmpty(
        'No batteries found\nTap to load',
        onTap: _loadBatteries,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBatteries,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _batteries.length,
        itemBuilder: (_, i) => _buildBatteryCard(_batteries[i]),
      ),
    );
  }

  Widget _buildBatteryCard(Battery bat) {
    final color = bat.isOnline
        ? AppColors.online
        : bat.isAlarm
        ? AppColors.alarm
        : AppColors.offline;
    return _buildDeviceCard(
      icon: Icons.battery_charging_full_rounded,
      iconColor: color,
      title: bat.batteryName ?? bat.sn,
      subtitle: (bat.stationName?.isNotEmpty == true)
          ? '${bat.stationName} | SN: ${bat.sn}'
          : 'SN: ${bat.sn}',
      statusText: bat.statusText,
      statusColor: color,
      metrics: [
        _DeviceMetricData(value: bat.socDisplay, label: 'SOC'),
        _DeviceMetricData(
          value:
              '${bat.batteryPower?.toStringAsFixed(1) ?? "0"} ${bat.batteryPowerStr ?? "W"}',
          label: 'Power',
        ),
        _DeviceMetricData(
          value:
              '${bat.batteryTodayChargeEnergy?.toStringAsFixed(1) ?? "0"} ${bat.batteryTodayChargeEnergyStr ?? "kWh"}',
          label: 'Charge',
        ),
      ],
      timeText: _formatDeviceTime(bat.dataTimestamp, bat.dataTimestampStr),
    );
  }

  // ─── DATALOGGER TAB ───────────────────────────────────────

  Widget _buildDataloggerTab() {
    if (_isLoadingCollectors) return _buildLoading();
    if (_collectors.isEmpty) {
      return _buildEmpty(
        'No dataloggers found\nTap to load',
        onTap: _loadCollectors,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCollectors,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: _collectors.length,
        itemBuilder: (_, i) => _buildCollectorCard(_collectors[i]),
      ),
    );
  }

  Widget _buildCollectorCard(Collector col) {
    final color = col.isOnline ? AppColors.online : AppColors.offline;
    return _buildDeviceCard(
      icon: Icons.router_rounded,
      iconColor: color,
      title: col.collectorName ?? col.sn,
      subtitle: (col.stationName?.isNotEmpty == true)
          ? '${col.stationName} | SN: ${col.sn}'
          : 'SN: ${col.sn}',
      statusText: col.statusText,
      statusColor: color,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CollectorDetailScreen(collector: col),
        ),
      ),
      metrics: [
        _DeviceMetricData(value: col.statusText, label: 'Status'),
        _DeviceMetricData(value: col.firmwareVersion ?? '-', label: 'FW'),
        _DeviceMetricData(
          value: '${col.inverterCount ?? 0}',
          label: 'Inverters',
        ),
      ],
      timeText: _formatDeviceTime(col.dataTimestamp, col.dataTimestampStr),
    );
  }

  Widget _buildDeviceCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String statusText,
    required Color statusColor,
    required List<_DeviceMetricData> metrics,
    required String timeText,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _dashboardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dashboardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(icon, size: 16, color: iconColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _textOnDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: _mutedOnDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: metrics
                      .take(3)
                      .map(
                        (m) => Expanded(
                          child: _plantMetric(value: m.value, label: m.label),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.update_rounded,
                      size: 14,
                      color: _mutedOnDark,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Last update $timeText',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _mutedOnDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'More',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDeviceTime(int? timestamp, String? timestampStr) {
    if (timestamp != null && timestamp > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${dt.day.toString().padLeft(2, '0')} ${_monthShort(dt.month)} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (timestampStr != null && timestampStr.trim().isNotEmpty) {
      return timestampStr.trim();
    }
    return '-';
  }

  String _monthShort(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > 12) return '-';
    return m[month - 1];
  }

  // ─── SHARED WIDGETS ───────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildEmpty(String msg, {VoidCallback? onTap}) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: AppColors.textTertiary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: _mutedOnDark,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 80).clamp(0.0, double.infinity)
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
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
                    size: 44,
                    color: AppColors.alarm,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connection Error',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textOnDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  msg,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _mutedOnDark),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadStations,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _plantsRealtimeTimer?.cancel();
    _tabController.dispose();
    _repository.dispose();
    super.dispose();
  }
}
