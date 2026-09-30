import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/growatt/growatt_device.dart';
import '../models/growatt/growatt_plant.dart';
import '../models/growatt/growatt_power_point.dart';
import '../services/growatt/growatt_monitoring_service.dart';
import '../widgets/plant_health_banner.dart';
import '../widgets/shimmer_loading.dart';

const _growattGreen = Color(0xFF16A34A);
const _growattGreenLight = Color(0xFFF0FDF4);
const _detailBlue = Color(0xFF6C82D8);
const _detailPurple = Color(0xFF8E7CE8);
const _detailInk = Color(0xFF1F2937);
const _detailMuted = Color(0xFF7A8799);

class GrowattPlantDetailScreen extends StatefulWidget {
  final GrowattPlant plant;

  const GrowattPlantDetailScreen({super.key, required this.plant});

  @override
  State<GrowattPlantDetailScreen> createState() =>
      _GrowattPlantDetailScreenState();
}

class _GrowattPlantDetailScreenState extends State<GrowattPlantDetailScreen> {
  final GrowattMonitoringService _service = GrowattMonitoringService();
  final List<double> _powerSamples = [];
  GrowattPlant? _plant;
  List<GrowattDevice> _devices = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastSuccessfulSync;

  GrowattPlant get _currentPlant => _plant ?? widget.plant;

  @override
  void initState() {
    super.initState();
    _plant = widget.plant;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _guard(_service.getRealtimePlant(widget.plant.plantCode)),
        _guard(_service.getDevices(widget.plant.plantCode)),
        _guard(_service.getPowerPoints(widget.plant.plantCode)),
      ]);
      final realtime = results[0] as GrowattPlant?;
      final devices = results[1] as List<GrowattDevice>?;
      final powerPoints = results[2] as List<GrowattPowerPoint>?;
      if (!mounted) return;
      final merged = realtime == null
          ? _currentPlant
          : widget.plant.mergeRealtime(realtime);
      setState(() {
        _plant = merged;
        if (devices != null) _devices = devices;
        if (realtime != null || devices != null || powerPoints != null) {
          _lastSuccessfulSync = DateTime.now();
        }
        if (powerPoints != null) {
          _setPowerSamples(powerPoints, merged.currentPower);
        } else {
          _appendPowerSample(merged.currentPower);
        }
        _errorMessage =
            realtime == null && devices == null && powerPoints == null
            ? 'Detail Growatt belum tersinkron. Tarik untuk refresh.'
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Menampilkan data terakhir Growatt. Tarik untuk refresh.';
        _appendPowerSample(_currentPlant.currentPower);
        _isLoading = false;
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

  void _appendPowerSample(double value) {
    _powerSamples.add(value);
    if (_powerSamples.length > 12) _powerSamples.removeAt(0);
    if (_powerSamples.length == 1) {
      _powerSamples.add(value);
      _powerSamples.add(value);
    }
  }

  void _setPowerSamples(List<GrowattPowerPoint> points, double fallback) {
    final samples = points
        .map((point) => point.power)
        .where((power) => power >= 0)
        .toList();
    _powerSamples
      ..clear()
      ..addAll(
        samples.length > 24 ? samples.sublist(samples.length - 24) : samples,
      );
    if (_powerSamples.isEmpty) {
      _appendPowerSample(fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = _currentPlant;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDetail,
          color: _growattGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(plant)),
              if (_errorMessage != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  sliver: SliverToBoxAdapter(child: _buildErrorBanner()),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: PlantHealthBanner(
                    providerName: 'Growatt',
                    isOnline: plant.isOnline,
                    statusLabel: plant.status,
                    updatedAt: plant.updatedAt,
                    fallbackSyncTime: _lastSuccessfulSync,
                    offlineDevices: _devices
                        .where((device) => !device.isOnline)
                        .length,
                    totalDevices: _devices.length,
                    isRefreshing: _isLoading,
                    accentColor: _growattGreen,
                    onRefresh: _isLoading ? null : _loadDetail,
                  ),
                ),
              ),
              if (_isLoading)
                const SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        ShimmerLoading(height: 190, borderRadius: 22),
                        SizedBox(height: 12),
                        ShimmerLoading(height: 110, borderRadius: 18),
                        SizedBox(height: 12),
                        ShimmerLoading(height: 160, borderRadius: 18),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  sliver: SliverList.list(
                    children: [
                      _buildEnergyHero(plant),
                      const SizedBox(height: 14),
                      _buildPowerChart(plant),
                      const SizedBox(height: 12),
                      _buildEnergySummary(plant),
                      const SizedBox(height: 12),
                      _buildPlantInfo(plant),
                      const SizedBox(height: 12),
                      _buildMapLocation(plant),
                      const SizedBox(height: 16),
                      _buildSectionTitle('Inverter / Device List'),
                    ],
                  ),
                ),
                if (_devices.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'Device Growatt belum terdeteksi',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverList.builder(
                      itemCount: _devices.length,
                      itemBuilder: (_, index) =>
                          _buildDeviceCard(_devices[index]),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GrowattPlant plant) {
    final statusColor = _statusColor(plant.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              GestureDetector(
                onTap: _loadDetail,
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
          const SizedBox(height: 16),
          Text(
            plant.plantName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _pill('Growatt', _growattGreen),
              const SizedBox(width: 8),
              _pill(plant.status, statusColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerChart(GrowattPlant plant) {
    final maxValue =
        (_powerSamples.fold<double>(
                  plant.capacity,
                  (max, value) => value > max ? value : max,
                ) *
                1.25)
            .clamp(1.0, double.infinity);

    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Realtime Power',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${plant.currentPower.toStringAsFixed(2)} kW',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _growattGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxValue,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.surfaceBorder,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < _powerSamples.length; i++)
                        FlSpot(i.toDouble(), _powerSamples[i]),
                    ],
                    isCurved: true,
                    color: _growattGreen,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _growattGreen.withValues(alpha: 0.10),
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

  Widget _buildEnergyHero(GrowattPlant plant) {
    final intensity = plant.capacity <= 0
        ? 0.0
        : (plant.currentPower / plant.capacity).clamp(0.0, 1.0) * 100;
    final savings = plant.dailyEnergy * 1500;
    final co2Saved = plant.dailyEnergy * 0.72;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C82D8).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Today's Energy",
                style: TextStyle(
                  color: _detailMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _heroStatus(plant.status),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plant.dailyEnergy.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        color: _detailInk,
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${plant.currentPower.toStringAsFixed(2)} kW live output',
                      style: const TextStyle(
                        color: _detailMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 145,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/images/solar_panel_array_wide.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomLeft,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _heroMetric(
                      Icons.wb_sunny_outlined,
                      'Intensity',
                      '${intensity.toStringAsFixed(0)}%',
                      'of capacity',
                      _detailBlue,
                    ),
                    const SizedBox(height: 7),
                    _heroMetric(
                      Icons.savings_outlined,
                      'Savings',
                      'Rp ${_compactNumber(savings)}',
                      'estimated today',
                      _detailPurple,
                    ),
                    const SizedBox(height: 7),
                    _heroMetric(
                      Icons.eco_outlined,
                      'CO₂ Saved',
                      '${co2Saved.toStringAsFixed(1)} kg',
                      'estimated today',
                      _growattGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _detailBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: _detailBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plant.dailyEnergy.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        color: _detailInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Energy generated today',
                      style: TextStyle(color: _detailMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              _periodPill('Today'),
            ],
          ),
          const SizedBox(height: 14),
          _buildSoftTrend(),
          const SizedBox(height: 10),
          Row(
            children: [
              _heroFooterMetric(
                'Today',
                '${plant.dailyEnergy.toStringAsFixed(1)} kWh',
              ),
              _heroFooterMetric(
                'This month',
                '${plant.monthlyEnergy.toStringAsFixed(1)} kWh',
              ),
              _heroFooterMetric(
                'Lifetime',
                '${plant.totalEnergy.toStringAsFixed(1)} kWh',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(
    IconData icon,
    String label,
    String value,
    String helper,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _detailMuted, fontSize: 9),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: _detailInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                helper,
                style: const TextStyle(color: _detailMuted, fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoftTrend() {
    final values = _powerSamples.isEmpty
        ? [0.35, 0.55, 0.42, 0.72, 0.5, 0.78, 0.62]
        : _powerSamples.take(10).toList();
    final maxValue = values.fold<double>(
      1,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FractionallySizedBox(
                  heightFactor: (values[i] / maxValue).clamp(0.16, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: i == values.length - 2
                          ? _detailPurple
                          : _detailBlue.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heroFooterMetric(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailInk,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: _detailMuted, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStatus(String status) {
    final online = status.toLowerCase() == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (online ? _growattGreen : AppColors.warning).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 7,
            color: online ? _growattGreen : AppColors.warning,
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: online ? _growattGreen : AppColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppColors.surfaceBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _detailMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: _detailMuted,
          ),
        ],
      ),
    );
  }

  String _compactNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  Widget _buildEnergySummary(GrowattPlant plant) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            '${plant.dailyEnergy.toStringAsFixed(1)} kWh',
            'Daily',
            Icons.today_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            '${plant.monthlyEnergy.toStringAsFixed(1)} kWh',
            'Monthly',
            Icons.calendar_month_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            '${plant.yearlyEnergy.toStringAsFixed(1)} kWh',
            'Yearly',
            Icons.bar_chart_rounded,
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _growattGreen),
          const SizedBox(height: 8),
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

  Widget _buildPlantInfo(GrowattPlant plant) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Plant Info'),
          const SizedBox(height: 10),
          _infoRow('Plant Code', plant.plantCode),
          _infoRow('Capacity', '${plant.capacity.toStringAsFixed(1)} kWp'),
          _infoRow(
            'Total Energy',
            '${plant.totalEnergy.toStringAsFixed(1)} kWh',
          ),
          _infoRow('Address', plant.address.isEmpty ? '-' : plant.address),
          _infoRow('Grid Date', plant.gridConnectionDate ?? '-'),
          _infoRow('Updated', plant.updatedAt ?? '-'),
        ],
      ),
    );
  }

  Widget _buildMapLocation(GrowattPlant plant) {
    final location = plant.latitude.isNotEmpty && plant.longitude.isNotEmpty
        ? '${plant.latitude}, ${plant.longitude}'
        : (plant.address.isEmpty
              ? 'Koordinat plant belum tersedia'
              : plant.address);
    return Container(
      height: 128,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _growattGreenLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: _growattGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Navigasi ke plant',
            onPressed: location == 'Koordinat plant belum tersedia'
                ? null
                : () => _openMapLocation(
                    plant.latitude,
                    plant.longitude,
                    plant.address,
                  ),
            icon: const Icon(Icons.near_me_rounded, color: _growattGreen),
          ),
        ],
      ),
    );
  }

  Future<void> _openMapLocation(
    String latitude,
    String longitude,
    String address,
  ) async {
    final destination = latitude.isNotEmpty && longitude.isNotEmpty
        ? '$latitude,$longitude'
        : address;
    if (destination.trim().isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildDeviceCard(GrowattDevice device) {
    final color = _statusColor(device.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _pill(device.status, color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            device.sn.isEmpty ? device.type : '${device.type} | ${device.sn}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _tinyMetric(
                  '${device.currentPower.toStringAsFixed(2)} kW',
                  'Power',
                ),
              ),
              Expanded(
                child: _tinyMetric(
                  '${device.dailyEnergy.toStringAsFixed(1)} kWh',
                  'Today',
                ),
              ),
              Expanded(
                child: _tinyMetric(
                  '${device.totalEnergy.toStringAsFixed(1)} kWh',
                  'Total',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tinyMetric(String value, String label) {
    return Column(
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
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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

  Widget _buildSectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ??
                  'Menampilkan data terakhir Growatt. Tarik untuk refresh.',
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

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.surfaceBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
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
    _service.dispose();
    super.dispose();
  }
}
