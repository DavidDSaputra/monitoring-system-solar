import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/huawei/huawei_plant.dart';
import '../services/huawei/huawei_monitoring_service.dart';
import '../widgets/shimmer_loading.dart';
import 'huawei_plant_detail_screen.dart';

const _huaweiBlue = Color(0xFF2563EB);
const _huaweiBlueDark = Color(0xFF1D4ED8);
const _huaweiBlueLight = Color(0xFFEFF6FF);

class HuaweiDashboardScreen extends StatefulWidget {
  const HuaweiDashboardScreen({super.key});

  @override
  State<HuaweiDashboardScreen> createState() => _HuaweiDashboardScreenState();
}

class _HuaweiDashboardScreenState extends State<HuaweiDashboardScreen> {
  final HuaweiMonitoringService _service = HuaweiMonitoringService();
  final List<HuaweiPlant> _plants = [];
  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlants();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_isRefreshing) _loadPlants(showLoading: false, silentError: true);
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
      setState(() {
        _plants
          ..clear()
          ..addAll(plants);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || silentError) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Huawei data unavailable';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  int get _onlineCount => _plants.where((plant) => plant.isOnline).length;
  double get _totalCapacity =>
      _plants.fold(0, (sum, plant) => sum + plant.capacity);
  double get _currentPower =>
      _plants.fold(0, (sum, plant) => sum + plant.currentPower);
  double get _dailyEnergy =>
      _plants.fold(0, (sum, plant) => sum + plant.dailyEnergy);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadPlants(showLoading: false),
                  color: _huaweiBlue,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        sliver: SliverList.list(
                          children: [
                            if (_errorMessage != null) _buildErrorBanner(),
                            _buildSummary(),
                            const SizedBox(height: 16),
                            _buildSectionTitle(),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                            itemCount: 5,
                            itemBuilder: (_, _) => const PlantCardSkeleton(),
                          ),
                        )
                      else if (_plants.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList.builder(
                            itemCount: _plants.length,
                            itemBuilder: (_, index) =>
                                _buildPlantCard(_plants[index]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Huawei FusionSolar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Realtime PLTS monitoring',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _loadPlants(showLoading: false),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_huaweiBlueDark, Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _huaweiBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.memory_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'FusionSolar Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _summaryMetric('${_plants.length}', 'Plant')),
              Expanded(
                child: _summaryMetric(
                  '${_totalCapacity.toStringAsFixed(1)} kWp',
                  'Capacity',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  '${_currentPower.toStringAsFixed(2)} kW',
                  'Current Power',
                ),
              ),
              Expanded(
                child: _summaryMetric(
                  '${_dailyEnergy.toStringAsFixed(1)} kWh',
                  "Today's Energy",
                ),
              ),
              Expanded(child: _summaryMetric('$_onlineCount', 'Online')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        const Text(
          'Plant List',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          _isRefreshing ? 'Refreshing...' : '${_plants.length} records',
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildPlantCard(HuaweiPlant plant) {
    final statusColor = _statusColor(plant.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HuaweiPlantDetailScreen(plant: plant),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plant.plantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _badge('Huawei'),
                    const SizedBox(width: 6),
                    _statusBadge(plant.status, statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plant.address.isEmpty ? plant.plantCode : plant.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _plantMetric(
                        '${plant.currentPower.toStringAsFixed(2)} kW',
                        'Power',
                      ),
                    ),
                    Expanded(
                      child: _plantMetric(
                        '${plant.dailyEnergy.toStringAsFixed(1)} kWh',
                        'Today',
                      ),
                    ),
                    Expanded(
                      child: _plantMetric(
                        '${plant.totalEnergy.toStringAsFixed(1)} kWh',
                        'Total',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.solar_power_rounded,
                      size: 14,
                      color: _huaweiBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${plant.capacity.toStringAsFixed(1)} kWp',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.textTertiary,
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

  Widget _plantMetric(String value, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _huaweiBlueLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _huaweiBlueDark,
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alarm.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.alarm.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.alarm,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'Huawei data unavailable',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Huawei data unavailable',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
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
