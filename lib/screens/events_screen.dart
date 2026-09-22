import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/alarm.dart';
import '../repositories/monitoring_repository.dart';
import '../widgets/shimmer_loading.dart';
import 'alarm_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final MonitoringRepository _repository = MonitoringRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Alarm> _alarms = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _statusFilter = 0; // 0 active, 1 recovered, 2 all
  int _levelFilter = 0; // 0 all, 1 info, 2 warning, 3 severe
  bool _isSearchOpen = false;
  String _query = '';

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

  List<Alarm> get _filteredAlarms {
    final byStatus = switch (_statusFilter) {
      0 => _alarms.where((alarm) => !alarm.isRecovered),
      1 => _alarms.where((alarm) => alarm.isRecovered),
      _ => _alarms,
    };

    final byLevel = _levelFilter == 0
        ? byStatus
        : byStatus.where((alarm) => alarm.alarmLevel == _levelFilter);

    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return byLevel.toList();

    return byLevel.where((alarm) {
      final searchable = [
        alarm.title,
        alarm.stationName ?? '',
        alarm.alarmDeviceSn,
        alarm.alarmCode ?? '',
        alarm.levelText,
        alarm.statusText,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  int get _activeCount => _alarms.where((alarm) => !alarm.isRecovered).length;
  int get _recoveredCount => _alarms.where((alarm) => alarm.isRecovered).length;

  @override
  void dispose() {
    _searchController.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_isSearchOpen) _buildSearchBar(),
            _buildToolbar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _headerTab('Alarm', 0, AppColors.primary),
                const SizedBox(width: 26),
                _headerTab('Recovered', 1, AppColors.textSecondary),
              ],
            ),
          ),
          _roundAction(
            _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
            () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  _query = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _headerTab(String label, int index, Color color) {
    final selected = _statusFilter == index;
    final count = index == 0 ? _activeCount : _recoveredCount;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = index),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: selected ? AppColors.primary : color,
            ),
          ),
          const SizedBox(width: 4),
          if (count > 0)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: selected ? AppColors.alarm : AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, size: 19),
            hintText: 'Search alarm, plant, device SN, or code',
            hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _filterChip('Active', 0, _statusFilter == 0, () {
            setState(() => _statusFilter = 0);
          }),
          const SizedBox(width: 8),
          _filterChip('Recovered', 1, _statusFilter == 1, () {
            setState(() => _statusFilter = 1);
          }),
          const SizedBox(width: 8),
          _levelChip('All', 0),
          const SizedBox(width: 8),
          _levelChip('Info', 1),
          const SizedBox(width: 8),
          _levelChip('Warning', 2),
          const SizedBox(width: 8),
          _levelChip('Severe', 3),
        ],
      ),
    );
  }

  Widget _levelChip(String label, int value) {
    return _filterChip(label, value, _levelFilter == value, () {
      setState(() => _levelFilter = value);
    });
  }

  Widget _filterChip(
    String label,
    int value,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        itemCount: 5,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerLoading(height: 118, borderRadius: 18),
        ),
      );
    }

    if (_errorMessage != null) return _buildErrorState();

    final alarms = _filteredAlarms;
    if (alarms.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadAlarms,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: alarms.length,
        itemBuilder: (context, index) =>
            _buildAlarmCard(context, alarms[index]),
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, Alarm alarm) {
    final color = _levelColor(alarm);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AlarmDetailScreen(alarm: alarm)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _severityBadge(alarm.levelText, color),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${alarm.alarmCode ?? '-'}  ${alarm.title}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!alarm.isRecovered)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.alarm,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${alarm.stationName ?? 'Unknown plant'}   ${alarm.deviceTypeText}: ${alarm.alarmDeviceSn}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${alarm.alarmBeginTimeStr ?? '-'}  -  ${alarm.isRecovered ? 'Recovered' : 'Ongoing'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      alarm.statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: alarm.isRecovered
                            ? AppColors.online
                            : AppColors.alarm,
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.alarm),
            const SizedBox(height: 16),
            const Text(
              'Failed to load alarms',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAlarms, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 62,
            color: AppColors.textTertiary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 14),
          const Text(
            'No alarms found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another filter or pull to refresh.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _severityBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }

  Color _levelColor(Alarm alarm) {
    if (alarm.isRecovered) return AppColors.textSecondary;
    switch (alarm.alarmLevel) {
      case 1:
        return const Color(0xFFEAB308);
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.alarm;
      default:
        return AppColors.primary;
    }
  }
}
