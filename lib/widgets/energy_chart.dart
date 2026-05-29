import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_theme.dart';
import '../models/energy_data.dart';

class EnergyChart extends StatelessWidget {
  final List<EnergyData> dataPoints;
  final String title;
  final bool showPower; // true = show power (kW), false = show energy (kWh)

  const EnergyChart({
    super.key,
    required this.dataPoints,
    this.title = 'Energy Production Today',
    this.showPower = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: dataPoints.isEmpty ? const _EmptyChart() : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < dataPoints.length; i++) {
      final value = showPower
          ? (dataPoints[i].power ?? 0)
          : (dataPoints[i].energy ?? 0);
      spots.add(FlSpot(i.toDouble(), value));
      if (value > maxY) maxY = value;
    }

    if (maxY == 0) maxY = 1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.chartGrid.withValues(alpha: 0.5),
            strokeWidth: 0.5,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(value >= 10 ? 0 : 1),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: dataPoints.length > 12
                  ? (dataPoints.length / 6).ceilToDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dataPoints.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dataPoints[index].time,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.1,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => Colors.white,
            tooltipRoundedRadius: 8,
            tooltipBorder: const BorderSide(
              color: AppColors.surfaceBorder,
              width: 1,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final time = index < dataPoints.length
                    ? dataPoints[index].time
                    : '';
                return LineTooltipItem(
                  '$time\n',
                  const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  children: [
                    TextSpan(
                      text:
                          '${spot.y.toStringAsFixed(2)} ${showPower ? 'kW' : 'kWh'}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            color: AppColors.chartLine,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.chartLine.withValues(alpha: 0.25),
                  AppColors.chartLine.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: AppColors.textTertiary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          const Text(
            'No data available',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
