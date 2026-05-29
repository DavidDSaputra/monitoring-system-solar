import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/inverter.dart';

class InverterDetailScreen extends StatelessWidget {
  final Inverter inverter;

  const InverterDetailScreen({super.key, required this.inverter});

  @override
  Widget build(BuildContext context) {
    final hasElectricalData =
        inverter.uAc1 != null ||
        inverter.iAc1 != null ||
        inverter.uPv1 != null ||
        inverter.iPv1 != null ||
        inverter.fac != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(context)),
            SliverToBoxAdapter(child: _buildStatisticSection()),
            SliverToBoxAdapter(child: _buildEnergyCards()),
            if (hasElectricalData)
              SliverToBoxAdapter(child: _buildElectricalParams()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceBorder),
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFFF7ED)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _buildCircleButton(icon: Icons.more_vert_rounded),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              inverter.inverterName ?? 'Panels',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatLargeNumber(inverter.eToday ?? 0)} ${inverter.eTodayStr ?? "kWh"}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Total Energy Produced',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _buildSolarPreview(),
            const SizedBox(height: 12),
            _buildTopMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
    );
  }

  Widget _buildSolarPreview() {
    return const _HoverInverterPreview(
      assetPath: 'assets/images/inverter_product.png',
    );
  }

  Widget _buildTopMetrics() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Capacity',
                  inverter.power != null
                      ? '${_formatLargeNumber(inverter.power!)} ${inverter.powerStr ?? "kW"}'
                      : '-',
                ),
              ),
              _buildMetricDivider(),
              Expanded(
                child: _buildMetricItem(
                  'Today',
                  '${_formatLargeNumber(inverter.eToday ?? 0)} ${inverter.eTodayStr ?? "kWh"}',
                ),
              ),
              _buildMetricDivider(),
              Expanded(
                child: _buildMetricItem(
                  'Total',
                  '${_formatLargeNumber(inverter.eTotal ?? 0)} ${inverter.eTotalStr ?? "kWh"}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(width: 1, height: 34, color: AppColors.surfaceBorder);
  }

  Widget _buildStatisticSection() {
    final statusColor = inverter.isOnline
        ? const Color(0xFF26D07C)
        : inverter.isAlarm
        ? const Color(0xFFFF6565)
        : const Color(0xFF9A9A9A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Statistic',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.double_arrow_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusNode(
                  icon: Icons.bolt_rounded,
                  fill: AppColors.surfaceLight,
                  iconColor: AppColors.textPrimary,
                ),
                _buildStatusNode(
                  icon: Icons.solar_power_rounded,
                  fill: AppColors.primaryLight,
                  iconColor: AppColors.primaryDark,
                  size: 66,
                ),
                _buildStatusNode(
                  icon: inverter.batteryCapacitySoc != null
                      ? Icons.battery_charging_full_rounded
                      : Icons.memory_rounded,
                  fill: AppColors.surfaceLight,
                  iconColor: AppColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: 200,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Column(
                children: [
                  Text(
                    inverter.stationName ?? 'Inverter Zone',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    inverter.pacDisplay,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status ${inverter.statusText}',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusNode({
    required IconData icon,
    required Color fill,
    required Color iconColor,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.45),
    );
  }

  Widget _buildEnergyCards() {
    final cards = <_EnergyCardData>[
      _EnergyCardData(
        title: 'Today Energy',
        value:
            '${_formatLargeNumber(inverter.eToday ?? 0)} ${inverter.eTodayStr ?? "kWh"}',
        subtitle: 'Energy Produced',
      ),
      _EnergyCardData(
        title: 'This Month',
        value:
            '${_formatLargeNumber(inverter.eMonth ?? 0)} ${inverter.eMonthStr ?? "kWh"}',
        subtitle: 'Energy Produced',
      ),
      _EnergyCardData(
        title: 'This Year',
        value:
            '${_formatLargeNumber(inverter.eYear ?? 0)} ${inverter.eYearStr ?? "kWh"}',
        subtitle: 'Energy Produced',
      ),
      _EnergyCardData(
        title: 'All-Time',
        value:
            '${_formatLargeNumber(inverter.eTotal ?? 0)} ${inverter.eTotalStr ?? "kWh"}',
        subtitle: 'Lifetime Output',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (_, index) => _buildEnergyCard(cards[index]),
      ),
    );
  }

  Widget _buildEnergyCard(_EnergyCardData card) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFFBF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.more_vert_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const Spacer(),
          Text(
            card.value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectricalParams() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Electrical Parameters',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (inverter.uAc1 != null)
              _paramRow('AC Voltage', '${inverter.uAc1!.toStringAsFixed(1)} V'),
            if (inverter.iAc1 != null)
              _paramRow('AC Current', '${inverter.iAc1!.toStringAsFixed(2)} A'),
            if (inverter.uPv1 != null)
              _paramRow(
                'PV1 Voltage',
                '${inverter.uPv1!.toStringAsFixed(1)} V',
              ),
            if (inverter.iPv1 != null)
              _paramRow(
                'PV1 Current',
                '${inverter.iPv1!.toStringAsFixed(2)} A',
              ),
            if (inverter.fac != null)
              _paramRow(
                'Frequency',
                '${inverter.fac!.toStringAsFixed(2)} ${inverter.facStr ?? "Hz"}',
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _paramRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.surfaceBorder),
      ],
    );
  }

  String _formatLargeNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(1);
  }
}

class _EnergyCardData {
  final String title;
  final String value;
  final String subtitle;

  const _EnergyCardData({
    required this.title,
    required this.value,
    required this.subtitle,
  });
}

class _HoverInverterPreview extends StatefulWidget {
  final String assetPath;

  const _HoverInverterPreview({required this.assetPath});

  @override
  State<_HoverInverterPreview> createState() => _HoverInverterPreviewState();
}

class _HoverInverterPreviewState extends State<_HoverInverterPreview> {
  bool _active = false;

  void _setActive(bool value) {
    if (_active == value) return;
    setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => _setActive(true),
      onExit: (event) => _setActive(false),
      child: GestureDetector(
        onTapDown: (details) => _setActive(true),
        onTapUp: (details) => _setActive(false),
        onTapCancel: () => _setActive(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 230,
          width: double.infinity,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _active ? -4.0 : 0.0, 0.0, 1.0),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _active ? AppColors.primary : AppColors.surfaceBorder,
            ),
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFFF7ED)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: _active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                scale: _active ? 1.035 : 1.0,
                child: Image.asset(
                  widget.assetPath,
                  fit: BoxFit.contain,
                  height: 190,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.solar_power_rounded,
                    size: 68,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 170),
                  opacity: _active ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'Inverter Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
