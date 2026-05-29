import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/alarm.dart';
import '../repositories/monitoring_repository.dart';
import '../widgets/shimmer_loading.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final MonitoringRepository _repository = MonitoringRepository();
  List<Alarm> _alarms = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final alarms = await _repository.getAlarms(forceRefresh: true);
      if (mounted) {
        setState(() {
          _alarms = alarms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('System Events & Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAlarms,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(height: 100, borderRadius: 12),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.alarm),
            const SizedBox(height: 16),
            const Text(
              'Failed to load alarms',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAlarms, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_alarms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Alarms',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your system is running smoothly.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlarms,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _alarms.length,
        itemBuilder: (context, index) {
          final alarm = _alarms[index];
          return _buildAlarmCard(alarm);
        },
      ),
    );
  }

  Widget _buildAlarmCard(Alarm alarm) {
    Color levelColor;
    IconData levelIcon;

    switch (alarm.alarmLevel) {
      case 1:
        levelColor = AppColors.online;
        levelIcon = Icons.info_outline_rounded;
        break;
      case 2:
        levelColor = AppColors.warning;
        levelIcon = Icons.warning_amber_rounded;
        break;
      case 3:
      default:
        levelColor = AppColors.alarm;
        levelIcon = Icons.error_outline_rounded;
        break;
    }

    if (alarm.isRecovered) {
      levelColor = AppColors.textSecondary;
      levelIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(left: BorderSide(color: levelColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(levelIcon, color: levelColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alarm.alarmName ?? 'Unknown Alarm',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alarm.isRecovered ? 'Recovered' : alarm.levelText,
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alarm.alarmMsg ?? 'No detail provided',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.device_hub_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Device: ${alarm.alarmDeviceSn}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Text(
                  alarm.alarmBeginTimeStr ?? 'Unknown time',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (alarm.stationName != null && alarm.stationName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.solar_power_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Plant: ${alarm.stationName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
