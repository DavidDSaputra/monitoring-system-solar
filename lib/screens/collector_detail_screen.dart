import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/collector.dart';
import '../repositories/monitoring_repository.dart';

class CollectorDetailScreen extends StatefulWidget {
  final Collector collector;

  const CollectorDetailScreen({super.key, required this.collector});

  @override
  State<CollectorDetailScreen> createState() => _CollectorDetailScreenState();
}

class _CollectorDetailScreenState extends State<CollectorDetailScreen> {
  final _repository = MonitoringRepository();
  Collector? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repository.getCollectorDetail(
        widget.collector.sn,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = _detail ?? widget.collector;
    final statusColor = col.isOnline ? AppColors.online : AppColors.offline;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _header(context, col, statusColor)),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _LoadingCard(),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _errorCard(_error!),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _identityCard(col),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _networkCard(col),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _rawCard(col),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Collector col, Color statusColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.textSecondary,
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(
              Icons.router_rounded,
              size: 18,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  col.collectorName ?? 'Datalogger',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SN: ${col.sn}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              col.statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(Collector col) {
    return _card(
      title: 'Device Info',
      child: Column(
        children: [
          _kv('Station', col.stationName ?? '-'),
          _kv('Type', col.collectorType ?? '-'),
          _kv('Firmware', col.firmwareVersion ?? '-'),
          _kv('Inverters', '${col.inverterCount ?? 0}'),
          _kv(
            'Signal',
            col.signalStrengthStr ?? (col.signalStrength?.toString() ?? '-'),
          ),
        ],
      ),
    );
  }

  Widget _networkCard(Collector col) {
    return _card(
      title: 'Network',
      child: Column(
        children: [
          _kv('MAC', col.macAddress ?? '-'),
          _kv('SSID', col.ssid ?? '-'),
          _kv('LAN IP', col.ipAddress ?? '-'),
          _kv('LAN API', col.lanApi ?? '-'),
        ],
      ),
    );
  }

  Widget _rawCard(Collector col) {
    final pretty = const JsonEncoder.withIndent('  ').convert(col.raw);
    return _card(
      title: 'Raw API Data',
      subtitle: '${col.raw.length} keys',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: SelectableText(
            pretty,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return _card(
      title: 'Failed to load',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
