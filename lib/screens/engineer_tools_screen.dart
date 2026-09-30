import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/incident.dart';
import '../services/incident_report_service.dart';
import '../services/incident_service.dart';
import '../services/push_notification_navigation_service.dart';
import '../services/push_notification_service.dart';

class EngineerToolsScreen extends StatefulWidget {
  const EngineerToolsScreen({super.key});

  @override
  State<EngineerToolsScreen> createState() => _EngineerToolsScreenState();
}

class _EngineerToolsScreenState extends State<EngineerToolsScreen> {
  final IncidentService _service = IncidentService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<Incident> _incidents = [];
  String _filter = 'all';
  String? _error;
  bool _loading = true;
  bool _exporting = false;
  bool _offline = false;
  DateTime? _cachedAt;

  @override
  void initState() {
    super.initState();
    _listenConnectivity();
    _load();
  }

  Future<void> _listenConnectivity() async {
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    if (mounted) {
      setState(() => _offline = initial.contains(ConnectivityResult.none));
    }
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (mounted) {
        setState(() => _offline = results.contains(ConnectivityResult.none));
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getIncidents();
      if (!mounted) return;
      setState(() {
        _incidents = result.records;
        _offline = _offline || result.offline;
        _cachedAt = result.cachedAt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _service.dispose();
    super.dispose();
  }

  List<Incident> get _filtered {
    return switch (_filter) {
      'open' => _incidents.where((item) => item.isOpen).toList(),
      'resolved' => _incidents.where((item) => !item.isOpen).toList(),
      'p1' => _incidents.where((item) => item.priority == 'P1').toList(),
      _ => _incidents,
    };
  }

  Future<void> _export(bool pdf) async {
    if (_exporting || _filtered.isEmpty) return;
    setState(() => _exporting = true);
    try {
      if (pdf) {
        await IncidentReportService.sharePdf(_filtered);
      } else {
        await IncidentReportService.shareExcel(_filtered);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ekspor gagal: $error')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openMap(Incident incident) async {
    final destination = incident.latitude != null && incident.longitude != null
        ? '${incident.latitude},${incident.longitude}'
        : [
            incident.plantName,
            incident.address,
          ].where((value) => value.trim().isNotEmpty).join(', ');
    if (destination.isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openPlant(Incident incident) {
    PushNotificationNavigationService.open(
      PushNavigationRequest(
        type: incident.entityType == 'plant' ? 'plant_status' : 'device_status',
        source: incident.source,
        plantCode: incident.plantCode,
        plantName: incident.plantName,
        event: incident.isOpen ? 'issue' : 'recovered',
        status: incident.isOpen ? incident.status : 'online',
        tab: incident.isOpen ? 'alarm' : 'overview',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              if (_offline) SliverToBoxAdapter(child: _offlineBanner()),
              SliverToBoxAdapter(child: _summary()),
              SliverToBoxAdapter(child: _actions()),
              SliverToBoxAdapter(child: _filters()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(hasScrollBody: false, child: _errorState())
              else if (_filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyIncidentState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 118),
                  sliver: SliverList.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _incidentCard(_filtered[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9D5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.engineering_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engineer Center',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Gangguan, SLA, downtime & laporan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
    );
  }

  Widget _offlineBanner() {
    final detail = _cachedAt == null
        ? 'Menampilkan data terakhir yang tersimpan.'
        : 'Data tersimpan ${DateFormat('dd MMM, HH:mm').format(_cachedAt!)}.';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF7C873)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFB7791F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode offline aktif. $detail',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A5A12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final open = _incidents.where((item) => item.isOpen).length;
    final breached = _incidents.where((item) => item.slaBreached).length;
    final resolved = _incidents.where((item) => !item.isOpen).toList();
    final compliant = resolved.where((item) => !item.slaBreached).length;
    final compliance = resolved.isEmpty
        ? 100
        : (compliant * 100 / resolved.length).round();
    final downtimeSeconds = _incidents.fold<int>(
      0,
      (sum, item) => sum + item.durationSeconds,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.85,
        children: [
          _metric(
            'Gangguan aktif',
            '$open',
            Icons.warning_amber_rounded,
            const Color(0xFFE85D3F),
          ),
          _metric(
            'SLA terlewati',
            '$breached',
            Icons.timer_off_rounded,
            const Color(0xFF9B51E0),
          ),
          _metric(
            'Total downtime',
            _shortDuration(downtimeSeconds),
            Icons.history_rounded,
            const Color(0xFF4A78D0),
          ),
          _metric(
            'SLA compliance',
            '$compliance%',
            Icons.verified_rounded,
            const Color(0xFF28A77A),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _exportButton(
              'Laporan PDF',
              Icons.picture_as_pdf_rounded,
              true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _exportButton(
              'Laporan Excel',
              Icons.table_view_rounded,
              false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportButton(String label, IconData icon, bool pdf) {
    return OutlinedButton.icon(
      onPressed: _exporting || _filtered.isEmpty ? null : () => _export(pdf),
      icon: _exporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 13),
        side: const BorderSide(color: AppColors.surfaceBorder),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _filters() {
    const filters = {
      'all': 'Semua',
      'open': 'Aktif',
      'resolved': 'Selesai',
      'p1': 'P1 Kritis',
    };
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: filters.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(entry.value),
              onSelected: (_) => setState(() => _filter = entry.key),
              selectedColor: const Color(0xFFFFE8D7),
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              side: const BorderSide(color: AppColors.surfaceBorder),
              backgroundColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _incidentCard(Incident incident) {
    final color = _priorityColor(incident.priority);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: () => _openPlant(incident),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _pill(incident.priority, color),
                  const SizedBox(width: 7),
                  _pill(incident.source.toUpperCase(), const Color(0xFF4A78D0)),
                  const Spacer(),
                  Icon(
                    incident.isOpen
                        ? Icons.error_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: incident.isOpen ? color : const Color(0xFF28A77A),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                incident.entityName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_entityLabel(incident.entityType)} · ${incident.plantName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: _incidentMeta(
                      Icons.schedule_rounded,
                      incident.durationLabel,
                    ),
                  ),
                  Expanded(
                    child: _incidentMeta(
                      Icons.timer_rounded,
                      incident.slaBreached ? 'SLA terlewati' : 'SLA aman',
                      alert: incident.slaBreached,
                    ),
                  ),
                  if (incident.hasLocation)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Navigasi ke plant',
                      onPressed: () => _openMap(incident),
                      icon: const Icon(
                        Icons.near_me_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _incidentMeta(IconData icon, String text, {bool alert = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: alert ? AppColors.alarm : AppColors.textTertiary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: alert ? AppColors.alarm : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String priority) => switch (priority) {
    'P1' => const Color(0xFFE5484D),
    'P2' => const Color(0xFFF59E0B),
    _ => const Color(0xFF4A78D0),
  };

  String _entityLabel(String type) => switch (type) {
    'inverter' => 'Inverter',
    'battery' => 'Baterai',
    'datalogger' => 'Datalogger',
    _ => 'Plant',
  };

  String _shortDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}j ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _EmptyIncidentState extends StatelessWidget {
  const _EmptyIncidentState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 58, color: Color(0xFF35B98A)),
            SizedBox(height: 12),
            Text(
              'Belum ada riwayat gangguan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 5),
            Text(
              'SolarView akan mencatat gangguan plant dan perangkat secara otomatis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
