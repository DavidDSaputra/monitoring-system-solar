import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/growatt/growatt_device.dart';
import '../models/growatt/growatt_plant.dart';
import '../models/growatt/growatt_power_point.dart';
import '../services/growatt/growatt_monitoring_service.dart';
import 'growatt_plant_detail_screen.dart';

const _growattNavy = Color(0xFF2E2B69);
const _growattBlue = Color(0xFF265D96);
const _growattPanel = Color(0xFF2A326F);
const _growattTile = Color(0xFF294B82);
const _growattTileLight = Color(0xFF45689E);
const _growattCyan = Color(0xFF38D2D0);
const _growattGreen = Color(0xFF35C64A);
const _growattYellow = Color(0xFFF5E500);

class GrowattDashboardScreen extends StatefulWidget {
  const GrowattDashboardScreen({super.key});

  @override
  State<GrowattDashboardScreen> createState() => _GrowattDashboardScreenState();
}

class _GrowattDashboardScreenState extends State<GrowattDashboardScreen> {
  final GrowattMonitoringService _service = GrowattMonitoringService();
  final List<GrowattPlant> _plants = [];
  final List<GrowattDevice> _devices = [];
  final List<GrowattPowerPoint> _powerPoints = [];
  Timer? _refreshTimer;

  GrowattPlant? _selectedPlant;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isDetailLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlants();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_isRefreshing) {
        _loadPlants(showLoading: false, silentError: true);
      }
    });
  }

  Future<void> _loadPlants({
    bool showLoading = true,
    bool silentError = false,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    _isRefreshing = true;
    try {
      final plants = await _service.getPlants();
      if (!mounted) return;
      final selectedCode = _selectedPlant?.plantCode;
      final selected = plants.firstWhere(
        (plant) => plant.plantCode == selectedCode,
        orElse: () => plants.isNotEmpty
            ? plants.firstWhere(
                (plant) => plant.isOnline,
                orElse: () => plants.first,
              )
            : const GrowattPlant(
                source: 'growatt',
                plantName: 'Growatt Plant',
                plantCode: '',
                capacity: 0,
                currentPower: 0,
                dailyEnergy: 0,
                monthlyEnergy: 0,
                yearlyEnergy: 0,
                totalEnergy: 0,
                status: 'unknown',
                address: '',
                latitude: '',
                longitude: '',
              ),
      );

      setState(() {
        _plants
          ..clear()
          ..addAll(plants);
        _selectedPlant = selected.plantCode.isEmpty ? null : selected;
        _isLoading = false;
        _errorMessage = null;
      });

      if (selected.plantCode.isNotEmpty) {
        await _loadPlantDetail(selected, showLoading: showLoading);
      }
    } catch (_) {
      if (!mounted || silentError) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Growatt data unavailable';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadPlantDetail(
    GrowattPlant plant, {
    bool showLoading = true,
  }) async {
    if (showLoading && mounted) {
      setState(() => _isDetailLoading = true);
    }

    final results = await Future.wait([
      _guard(_service.getRealtimePlant(plant.plantCode)),
      _guard(_service.getDevices(plant.plantCode)),
      _guard(_service.getPowerPoints(plant.plantCode)),
    ]);
    if (!mounted) return;

    final realtime = results[0] as GrowattPlant?;
    final devices = results[1] as List<GrowattDevice>?;
    final points = results[2] as List<GrowattPowerPoint>?;

    if (realtime == null && devices == null && points == null) {
      setState(() {
        _isDetailLoading = false;
        _errorMessage = 'Growatt detail unavailable';
      });
      return;
    }

    try {
      final merged = realtime == null ? plant : plant.mergeRealtime(realtime);
      final index = _plants.indexWhere((p) => p.plantCode == plant.plantCode);

      setState(() {
        if (index >= 0) _plants[index] = merged;
        _selectedPlant = merged;
        if (devices != null) {
          _devices
            ..clear()
            ..addAll(devices);
        }
        if (points != null) {
          _powerPoints
            ..clear()
            ..addAll(points);
        }
        _isDetailLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDetailLoading = false;
        _errorMessage = 'Growatt data unavailable';
      });
    }
  }

  Future<T?> _guard<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  void _selectPlant(GrowattPlant plant) {
    setState(() => _selectedPlant = plant);
    _loadPlantDetail(plant);
  }

  int get _selectedPlantIndex {
    final index = _plants.indexWhere(
      (plant) => plant.plantCode == _plant.plantCode,
    );
    return index < 0 ? 0 : index;
  }

  void _movePlantSelection(int delta) {
    if (_plants.isEmpty) return;
    final nextIndex = (_selectedPlantIndex + delta).clamp(
      0,
      _plants.length - 1,
    );
    _selectPlant(_plants[nextIndex]);
  }

  int get _onlineCount => _plants.where((plant) => plant.isOnline).length;
  double get _totalCapacity =>
      _plants.fold(0, (sum, plant) => sum + plant.capacity);
  GrowattPlant get _plant =>
      _selectedPlant ??
      const GrowattPlant(
        source: 'growatt',
        plantName: 'Growatt Plant',
        plantCode: '',
        capacity: 0,
        currentPower: 0,
        dailyEnergy: 0,
        monthlyEnergy: 0,
        yearlyEnergy: 0,
        totalEnergy: 0,
        status: 'unknown',
        address: '',
        latitude: '',
        longitude: '',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _growattCyan,
          onRefresh: () => _loadPlants(showLoading: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                sliver: SliverList.list(
                  children: [
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildPlantSwitcher(),
                    const SizedBox(height: 12),
                    _buildDeviceSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    return Container(
      padding: EdgeInsets.fromLTRB(22, 18, 22, isWide ? 28 : 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_growattNavy, _growattBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(isWide),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_isLoading ? 'growatt-loading' : 'growatt-ready'),
              child: _isLoading
                  ? _buildLoadingPanel()
                  : isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _softReveal(
                            index: 0,
                            child: _buildChartPanel(height: 340),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: _buildStatsGrid(height: 340)),
                      ],
                    )
                  : Column(
                      children: [
                        _softReveal(
                          index: 0,
                          child: _buildChartPanel(height: 290),
                        ),
                        const SizedBox(height: 12),
                        _buildStatsGrid(height: 420),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Current Location: Dashboard',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        if (isWide) _buildNavButtons(),
        const SizedBox(width: 14),
        _buildWeatherBlock(),
      ],
    );
  }

  Widget _buildNavButtons() {
    return Row(
      children: [
        _navButton(Icons.speed_rounded, 'Dashboard', true),
        _navButton(Icons.bar_chart_rounded, 'Energy', false),
        _navButton(Icons.article_rounded, 'Log', false),
        _navButton(Icons.settings_rounded, 'Setting', false),
      ],
    );
  }

  Widget _navButton(IconData icon, String label, bool active) {
    return Container(
      width: 74,
      height: 60,
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.26)
            : Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? Colors.white24 : Colors.transparent),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '29 C',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 18),
          ],
        ),
        Text(
          'Haze - ${_plant.address.isEmpty ? 'Growatt' : _plant.address.split(',').first}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        const SizedBox(height: 8),
        Text(
          '$_onlineCount/${_plants.length} online | ${_totalCapacity.toStringAsFixed(1)} kWp',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildLoadingPanel() {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _growattCyan),
      ),
    );
  }

  Widget _buildChartPanel({required double height}) {
    final spots = _chartSpots();
    final maxY = _maxChartValue(spots);

    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: _growattPanel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          _chartToolbar(),
          const SizedBox(height: 18),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.12),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Power(W)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: spots.length > 6 ? (spots.length / 5) : 1,
                      getTitlesWidget: (value, _) => Text(
                        _timeLabel(value.toInt()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _growattGreen,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _growattGreen.withValues(alpha: 0.22),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: _growattGreen, size: 9),
              SizedBox(width: 5),
              Text(
                'Photovoltaic Output',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Device Type',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _smallPill('Inverter', Icons.keyboard_arrow_down_rounded),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _datePill(compact: true),
                  const SizedBox(width: 8),
                  Expanded(child: _periodTabs(compact: true)),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            const Text(
              'Device Type',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 8),
            _smallPill('Inverter', Icons.keyboard_arrow_down_rounded),
            const Spacer(),
            _datePill(),
            const SizedBox(width: 8),
            _periodTabs(),
          ],
        );
      },
    );
  }

  Widget _smallPill(String text, IconData icon) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: Colors.white70, size: 15),
        ],
      ),
    );
  }

  Widget _datePill({bool compact = false}) {
    final date = DateTime.now().toIso8601String().split('T').first;
    return Container(
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white54,
              size: 14,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            compact ? date.substring(5) : date,
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
              size: 14,
            ),
          ],
        ],
      ),
    );
  }

  Widget _periodTabs({bool compact = false}) {
    const tabs = ['Hour', 'Day', 'Month', 'Year'];
    return Container(
      height: 22,
      width: compact ? null : 216,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final tab in tabs)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tab == 'Hour'
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tab,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({required double height}) {
    final plant = _plant;
    final compact = MediaQuery.sizeOf(context).width < 430;
    final tileHeight = compact ? 148.0 : height / 2;
    final items = [
      _softReveal(
        index: 1,
        child: _metricTile(
          icon: Icons.wb_sunny_rounded,
          iconColor: _growattCyan,
          title: 'Generation Today',
          value: plant.dailyEnergy.toStringAsFixed(1),
          unit: 'Today\nkWh',
          color: _growattTile,
        ),
      ),
      _softReveal(
        index: 2,
        child: _metricTile(
          icon: Icons.wb_sunny_rounded,
          iconColor: _growattCyan,
          title: 'Total Generation',
          value: plant.totalEnergy.toStringAsFixed(1),
          unit: 'Total\nkWh',
          color: _growattTile,
        ),
      ),
      _softReveal(
        index: 3,
        child: _metricTile(
          icon: Icons.attach_money_rounded,
          iconColor: _growattYellow,
          title: 'Today',
          value: '0',
          unit: 'Today\nRp',
          color: _growattTile,
        ),
      ),
      _softReveal(
        index: 4,
        child: _metricTile(
          icon: Icons.attach_money_rounded,
          iconColor: _growattYellow,
          title: 'Total Revenue',
          value: '0',
          unit: 'Total\nRp',
          color: _growattTileLight,
        ),
      ),
    ];

    return SizedBox(
      height: tileHeight * 2,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: tileHeight,
        ),
        itemBuilder: (_, index) => items[index],
      ),
    );
  }

  Widget _metricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 160 || constraints.maxWidth < 150;
        return Container(
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 10 : 14,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 40 : 46,
                  height: compact ? 40 : 46,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: compact ? 22 : 25,
                  ),
                ),
                SizedBox(height: compact ? 7 : 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 10 : 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 28 : 34,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Padding(
                      padding: EdgeInsets.only(bottom: compact ? 5 : 7),
                      child: Text(
                        unit,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 8 : 9,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlantSwitcher() {
    if (_plants.isEmpty) return const SizedBox.shrink();
    final selectedCode =
        _plants.any((plant) => plant.plantCode == _plant.plantCode)
        ? _plant.plantCode
        : _plants.first.plantCode;

    return _softReveal(
      index: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE3EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Plant',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFD8DEE9)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCode,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        onChanged: (plantCode) {
                          if (plantCode == null) return;
                          final plant = _plants.firstWhere(
                            (item) => item.plantCode == plantCode,
                            orElse: () => _plant,
                          );
                          if (plant.plantCode.isNotEmpty) _selectPlant(plant);
                        },
                        items: [
                          for (final plant in _plants)
                            DropdownMenuItem<String>(
                              value: plant.plantCode,
                              child: Text(
                                plant.plantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _plantStepButton(Icons.chevron_left_rounded, -1),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFD8DEE9)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_selectedPlantIndex + 1} / ${_plants.length}  ${_plant.plantName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _plantStepButton(Icons.chevron_right_rounded, 1),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final plant in _plants)
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _selectPlant(plant),
                    child: Container(
                      height: 36,
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: plant.plantCode == _plant.plantCode
                            ? _growattBlue
                            : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: plant.plantCode == _plant.plantCode
                              ? _growattBlue
                              : const Color(0xFFD8DEE9),
                        ),
                      ),
                      child: Text(
                        plant.plantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: plant.plantCode == _plant.plantCode
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
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

  Widget _plantStepButton(IconData icon, int delta) {
    final disabled =
        (delta < 0 && _selectedPlantIndex == 0) ||
        (delta > 0 && _selectedPlantIndex >= _plants.length - 1);
    return SizedBox(
      width: 40,
      height: 36,
      child: ElevatedButton(
        onPressed: disabled ? null : () => _movePlantSelection(delta),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: EdgeInsets.zero,
          backgroundColor: _growattBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5EAF2),
          disabledForegroundColor: AppColors.textTertiary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }

  Widget _buildDeviceSection() {
    return _softReveal(
      index: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE3EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'My Photovoltaic Devices',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  _isDetailLoading ? 'Refreshing...' : 'All Devices',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
            const SizedBox(height: 14),
            if (_devices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No Growatt devices found',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ..._devices.map(_buildDeviceCard),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(GrowattDevice device) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;
    return InkWell(
      onTap: _selectedPlant == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GrowattPlantDetailScreen(plant: _plant),
              ),
            ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDE3EE)),
        ),
        child: isWide
            ? Row(
                children: [
                  _deviceIdentity(device),
                  const SizedBox(width: 18),
                  Expanded(child: _deviceInfoGrid(device)),
                  const SizedBox(width: 18),
                  _deviceSettingButton(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _deviceIdentity(device),
                  const SizedBox(height: 14),
                  _deviceInfoGrid(device),
                  const SizedBox(height: 12),
                  _deviceSettingButton(),
                ],
              ),
      ),
    );
  }

  Widget _deviceIdentity(GrowattDevice device) {
    return SizedBox(
      width: 136,
      child: Column(
        children: [
          Text(
            device.sn.isEmpty ? device.name : device.sn,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 54,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF4EA5F5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Icon(
              Icons.developer_board_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceInfoGrid(GrowattDevice device) {
    final plant = _plant;
    return Wrap(
      runSpacing: 18,
      spacing: 28,
      children: [
        _deviceInfo('Device Serial Number:', device.sn),
        _deviceInfo(
          'Connection Status:',
          device.status,
          _statusColor(device.status),
        ),
        _deviceInfo('Update Time:', device.updatedAt ?? '-'),
        _deviceInfo(
          'Rated Power(W):',
          (plant.capacity * 1000).toStringAsFixed(1),
        ),
        _deviceInfo('User Name:', 'teknisjarwinn'),
        _deviceInfo('Plant Name:', plant.plantName),
        _deviceInfo('Data Logger:', device.type.isEmpty ? '-' : device.type),
        _deviceInfo(
          'Current Power(W):',
          (plant.currentPower * 1000).toStringAsFixed(1),
        ),
        _deviceInfo(
          'Generation Today(kWh):',
          plant.dailyEnergy.toStringAsFixed(1),
        ),
        _deviceInfo(
          'Monthly Power Generation(kWh):',
          plant.monthlyEnergy.toStringAsFixed(1),
        ),
        _deviceInfo(
          'Total Power Generation(kWh):',
          plant.totalEnergy.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _deviceInfo(String label, String value, [Color? valueColor]) {
    return SizedBox(
      width: 300,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value.isEmpty ? '-' : value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceSettingButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF9BD1FF)),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: Color(0xFF4EA5F5),
            size: 22,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Inverter Setting',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alarm.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.alarm.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.alarm),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'Growatt data unavailable',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softReveal({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 5) * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  List<FlSpot> _chartSpots() {
    final values = _powerPoints.map((point) => point.power).toList();
    if (values.isEmpty) {
      final currentWatts = (_plant.currentPower * 1000)
          .clamp(0, 100000)
          .toDouble();
      values.addAll([0, currentWatts * 0.4, currentWatts * 0.7, currentWatts]);
    }

    return [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i].clamp(0, 100000).toDouble()),
    ];
  }

  double _maxChartValue(List<FlSpot> spots) {
    final maxPower = spots.fold<double>(
      _plant.capacity * 1000,
      (max, spot) => spot.y > max ? spot.y : max,
    );
    return (maxPower * 1.18).clamp(1000, 100000).toDouble();
  }

  String _timeLabel(int index) {
    if (_powerPoints.isEmpty || index < 0 || index >= _powerPoints.length) {
      return '';
    }

    final raw = _powerPoints[index].time;
    final date = DateTime.tryParse(raw);
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'online' => AppColors.online,
      'warning' => AppColors.warning,
      'fault' => AppColors.alarm,
      _ => AppColors.offline,
    };
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
