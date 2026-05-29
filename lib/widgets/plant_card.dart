import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/station.dart';
import 'shimmer_loading.dart';

class PlantCard extends StatelessWidget {
  final Station station;
  final VoidCallback? onTap;

  const PlantCard({super.key, required this.station, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = station.isOnline
        ? AppColors.online
        : station.isAlarm
            ? AppColors.alarm
            : AppColors.offline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Status icon + Plant name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status dot with ring
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Icon(
                          station.isOnline
                              ? Icons.bolt_rounded
                              : station.isAlarm
                                  ? Icons.warning_rounded
                                  : Icons.power_off_rounded,
                          size: 11,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Plant name + address
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.stationName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (station.addr != null && station.addr!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              station.addr!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                height: 1.3,
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
                const SizedBox(height: 14),

                // Row 2: Stats (Daily Yield | Power | Capacity)
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        value: station.dayEnergy?.toStringAsFixed(1) ?? '0',
                        unit: station.dayEnergyStr ?? 'kWh',
                        label: 'Daily Yield',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        value: station.power?.toStringAsFixed(station.power != null && station.power! < 10 ? 2 : 1) ?? '0',
                        unit: station.powerStr ?? 'kW',
                        label: 'Power',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        value: station.capacity.toStringAsFixed(station.capacity < 10 ? 2 : 1),
                        unit: station.capacityStr ?? 'kWp',
                        label: 'Capacity',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 3: Update time + More button
                Row(
                  children: [
                    Icon(
                      station.isOnline ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${station.isOnline ? "" : "Offline Time:"}${station.formattedUpdateTime}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: const Text('More',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
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
}

class _StatItem extends StatelessWidget {
  final String value;
  final String unit;
  final String label;

  const _StatItem({
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Value + unit in one rich text
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: unit,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }
}

class PlantCardSkeleton extends StatelessWidget {
  const PlantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ShimmerLoading(height: 140, borderRadius: 16),
    );
  }
}
