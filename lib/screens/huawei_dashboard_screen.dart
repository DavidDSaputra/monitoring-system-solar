import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/huawei/huawei_alarm.dart';
import '../models/huawei/huawei_plant.dart';
import '../services/huawei/huawei_monitoring_service.dart';

const _fusionBlue = Color(0xFF1687E8);
const _fusionDark = Color(0xFF1F1F1F);
const _softBlue = Color(0xFFEFF6FF);
const _line = Color(0xFFE2E8F0);

class HuaweiDashboardScreen extends StatefulWidget {
  const HuaweiDashboardScreen({super.key});

  @override
  State<HuaweiDashboardScreen> createState() => _HuaweiDashboardScreenState();
}

class _HuaweiDashboardScreenState extends State<HuaweiDashboardScreen> {
  final HuaweiMonitoringService _service = HuaweiMonitoringService();
  final List<HuaweiPlant> _plants = [];
  final List<HuaweiAlarm> _alarms = [];
  Timer? _refreshTimer;

  HuaweiPlant? _selectedPlant;
  int _tabIndex = 0;
  bool _historicalAlarms = false;
  bool _isLoading = true;
  bool _isAlarmLoading = false;
  String? _errorMessage;
  String? _alarmError;

  HuaweiPlant get _plant =>
      _selectedPlant ??
      const HuaweiPlant(
        source: 'huawei',
        plantName: 'FusionSolar Plant',
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
  void initState() {
    super.initState();
    _loadPlants();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadPlants(showLoading: false);
    });
  }

  Future<void> _loadPlants({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final plants = await _service.getPlants();
      if (!mounted) return;
      final selectedCode = _selectedPlant?.plantCode;
      final selected = plants.firstWhere(
        (plant) => plant.plantCode == selectedCode,
        orElse: () => plants.isNotEmpty ? plants.first : _plant,
      );
      setState(() {
        _plants
          ..clear()
          ..addAll(plants);
        _selectedPlant = selected.plantCode.isEmpty ? null : selected;
        _isLoading = false;
      });
      _loadAlarms();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Huawei data unavailable';
      });
    }
  }

  Future<void> _loadAlarms() async {
    if (_plant.plantCode.isEmpty) return;
    setState(() {
      _isAlarmLoading = true;
      _alarmError = null;
    });

    try {
      final alarms = await _service.getAlarms(
        plantCode: _plant.plantCode,
        historical: _historicalAlarms,
      );
      if (!mounted) return;
      setState(() {
        _alarms
          ..clear()
          ..addAll(alarms);
        _isAlarmLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alarms.clear();
        _isAlarmLoading = false;
        _alarmError = 'Huawei alarm data unavailable';
      });
    }
  }

  void _selectPlant(String? plantCode) {
    if (plantCode == null) return;
    final plant = _plants.firstWhere(
      (item) => item.plantCode == plantCode,
      orElse: () => _plant,
    );
    setState(() => _selectedPlant = plant);
    _loadAlarms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildMobileTopBar(),
            Expanded(
              child: RefreshIndicator(
                color: _fusionBlue,
                onRefresh: () => _loadPlants(showLoading: false),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      sliver: SliverList.list(
                        children: [
                          if (_errorMessage != null)
                            _errorBanner(_errorMessage!),
                          _buildPlantSelector(),
                          const SizedBox(height: 12),
                          _buildTabs(),
                          const SizedBox(height: 14),
                          if (_isLoading)
                            _softReveal(
                              index: 0,
                              child: const SizedBox(
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _fusionBlue,
                                  ),
                                ),
                              ),
                            )
                          else
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0.02, 0.04),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(
                                  'huawei-tab-$_tabIndex-$_historicalAlarms',
                                ),
                                child: _tabIndex == 4
                                    ? _buildAlarmPage()
                                    : _buildOverviewPage(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTopBar() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: _fusionDark,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/fusionsolar-logo.jpg',
            width: 104,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text(
              'FusionSolar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          _topBadge('Monitoring'),
          IconButton(
            onPressed: () => _loadPlants(showLoading: false),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _topBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _fusionBlue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _fusionBlue,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildPlantSelector() {
    final value = _plants.any((plant) => plant.plantCode == _plant.plantCode)
        ? _plant.plantCode
        : (_plants.isEmpty ? null : _plants.first.plantCode);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _softBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_work_outlined, color: _fusionBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _plant.plantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _plant.status,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(_plant.status),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.cloudy_snowing, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Text(
                '25~33 C',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                hint: const Text('Select plant'),
                onChanged: _selectPlant,
                items: [
                  for (final plant in _plants)
                    DropdownMenuItem(
                      value: plant.plantCode,
                      child: Text(
                        plant.plantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Overview', 'Trend', 'Report', 'Device', 'Alarms', 'Users'];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final active = _tabIndex == index;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              setState(() => _tabIndex = index);
              if (index == 4) _loadAlarms();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _fusionBlue : Colors.white,
                border: Border.all(color: active ? _fusionBlue : _line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewPage() {
    return Column(
      children: [
        _buildKpiGrid(),
        const SizedBox(height: 12),
        _flowCard(),
        const SizedBox(height: 12),
        _alarmSummaryCard(),
        const SizedBox(height: 12),
        _plantInfoCard(),
      ],
    );
  }

  Widget _buildKpiGrid() {
    final items = [
      _Kpi('Yield today', _plant.dailyEnergy, 'kWh', Icons.wb_sunny_outlined),
      _Kpi(
        'This month',
        _plant.monthlyEnergy,
        'kWh',
        Icons.solar_power_outlined,
      ),
      _Kpi('This year', _plant.yearlyEnergy, 'kWh', Icons.solar_power_outlined),
      _Kpi(
        'Total yield',
        _plant.totalEnergy,
        'kWh',
        Icons.energy_savings_leaf_outlined,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 114,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) =>
          _softReveal(index: index, child: _kpiCard(items[index])),
    );
  }

  Widget _kpiCard(_Kpi item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: _softBlue,
            child: Icon(item.icon, color: _fusionBlue, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value.toStringAsFixed(2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item.unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Energy Flow',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 2,
                  height: 116,
                  color: const Color(0xFFFFC15A),
                ),
                Container(
                  width: 190,
                  height: 2,
                  color: const Color(0xFF93C5FD),
                ),
                Positioned(
                  top: 0,
                  child: _circleNode(
                    'PV',
                    '${_plant.currentPower.toStringAsFixed(2)} kW',
                    Icons.solar_power_outlined,
                    const Color(0xFFFFC15A),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 6,
                  child: _circleNode(
                    'Load',
                    '',
                    Icons.home_outlined,
                    const Color(0xFF7DD3FC),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 6,
                  child: _circleNode(
                    'Grid',
                    '',
                    Icons.electrical_services_outlined,
                    const Color(0xFFD8B4FE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleNode(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 24),
              if (value.isNotEmpty)
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _alarmSummaryCard() {
    final counts = _alarmCounts();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Alarm Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_alarms.length} Alarm',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final severity in ['critical', 'major', 'minor', 'warning'])
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      _title(severity),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _alarms.isEmpty
                            ? 0
                            : (counts[severity] ?? 0) / _alarms.length,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: _severityColor(severity),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${counts[severity] ?? 0}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _plantInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plant Info',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _infoRow(
            'Plant address',
            _plant.address.isEmpty ? '-' : _plant.address,
          ),
          _infoRow(
            'Total string capacity',
            '${_plant.capacity.toStringAsFixed(3)} kWp',
          ),
          _infoRow('Grid connection date', _plant.gridConnectionDate ?? '-'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmPage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _alarmTab('Active Alarms', false)),
              const SizedBox(width: 8),
              Expanded(child: _alarmTab('Historical', true)),
            ],
          ),
          const SizedBox(height: 14),
          _alarmToolbar(),
          const SizedBox(height: 14),
          if (_alarmError != null) _errorBanner(_alarmError!),
          if (_isAlarmLoading)
            const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: _fusionBlue),
              ),
            )
          else if (_alarms.isEmpty)
            _noAlarmState()
          else
            for (var i = 0; i < _alarms.length; i++)
              _softReveal(index: i, child: _alarmCard(_alarms[i])),
          const SizedBox(height: 10),
          Text(
            'Total: ${_alarms.length}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alarmTab(String label, bool historical) {
    final active = _historicalAlarms == historical;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() => _historicalAlarms = historical);
        _loadAlarms();
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _fusionBlue : const Color(0xFFF8FAFC),
          border: Border.all(color: active ? _fusionBlue : _line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _alarmToolbar() {
    final counts = _alarmCounts();
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _filterBox('Device type', 'All')),
            const SizedBox(width: 8),
            Expanded(child: _filterBox('SN', 'SN')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadAlarms,
            style: ElevatedButton.styleFrom(
              backgroundColor: _fusionBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Search'),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _severityPill(Icons.error, Colors.red, counts['critical'] ?? 0),
            _severityPill(Icons.bolt, Colors.deepOrange, counts['major'] ?? 0),
            _severityPill(
              Icons.error_outline,
              Colors.orange,
              counts['minor'] ?? 0,
            ),
            _severityPill(Icons.info, Colors.blue, counts['warning'] ?? 0),
          ],
        ),
      ],
    );
  }

  Widget _filterBox(String label, String hint) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $hint',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ],
      ),
    );
  }

  Widget _severityPill(IconData icon, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _noAlarmState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 42),
          SizedBox(height: 8),
          Text(
            'No data',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _alarmCard(HuaweiAlarm alarm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _severityChip(alarm.severity),
              const Spacer(),
              Text(
                _formatTime(alarm.occurrenceTime),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alarm.alarmName,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          _alarmInfo('Plant', alarm.plantName),
          _alarmInfo('Device', alarm.deviceName),
          _alarmInfo('SN', alarm.sn),
          _alarmInfo('Alarm ID', alarm.alarmId),
        ],
      ),
    );
  }

  Widget _severityChip(String severity) {
    final color = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _title(severity),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _alarmInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alarm.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.alarm.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _softReveal({required int index, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index.clamp(0, 5) * 45)),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Map<String, int> _alarmCounts() {
    final counts = <String, int>{
      'critical': 0,
      'major': 0,
      'minor': 0,
      'warning': 0,
    };
    for (final alarm in _alarms) {
      counts[alarm.severity] = (counts[alarm.severity] ?? 0) + 1;
    }
    return counts;
  }

  String _title(String value) {
    if (value.isEmpty) return '-';
    return value[0].toUpperCase() + value.substring(1);
  }

  Color _severityColor(String severity) {
    return switch (severity) {
      'critical' => Colors.red,
      'major' => Colors.deepOrange,
      'minor' => Colors.orange,
      'warning' => Colors.blue,
      _ => Colors.black45,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'online' => AppColors.online,
      'warning' => AppColors.warning,
      'fault' => AppColors.alarm,
      _ => AppColors.offline,
    };
  }

  String _formatTime(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _service.dispose();
    super.dispose();
  }
}

class _Kpi {
  final String label;
  final double value;
  final String unit;
  final IconData icon;

  const _Kpi(this.label, this.value, this.unit, this.icon);
}
