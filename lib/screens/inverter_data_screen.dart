import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/inverter.dart';
import '../repositories/monitoring_repository.dart';

class InverterDataScreen extends StatefulWidget {
  final Inverter inverter;

  const InverterDataScreen({super.key, required this.inverter});

  @override
  State<InverterDataScreen> createState() => _InverterDataScreenState();
}

class _InverterDataScreenState extends State<InverterDataScreen> {
  final _repository = MonitoringRepository();
  Inverter? _detail;
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
      final detail = await _repository.getInverterDetail(
        widget.inverter.sn,
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
    final inv = _detail ?? widget.inverter;
    final statusColor = inv.isOnline
        ? AppColors.online
        : inv.isAlarm
        ? AppColors.alarm
        : AppColors.offline;

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
              SliverToBoxAdapter(child: _header(context, inv, statusColor)),
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
                    child: _ErrorCard(),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _dcCard(inv),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _acCard(inv),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _generationCard(inv),
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

  Widget _header(BuildContext context, Inverter inv, Color statusColor) {
    final timeText =
        inv.dataTimestampStr ??
        (inv.dataTimestamp != null ? inv.dataTimestamp.toString() : '-');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppColors.textSecondary,
              ),
              const Expanded(
                child: Text(
                  'Inverter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.star_border_rounded, size: 20),
                color: AppColors.textSecondary,
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.menu_rounded, size: 22),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SN:${inv.sn}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        inv.statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _metricLine('Power', inv.pacDisplay),
                    _metricLine(
                      'Rated Power',
                      inv.power != null
                          ? '${inv.power!.toStringAsFixed(1)} ${inv.powerStr ?? "kW"}'
                          : '-',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Image.asset(
                  'assets/images/inverter_product.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.memory_rounded,
                    color: AppColors.primaryDark,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricLine(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
          Text(
            v,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dcCard(Inverter inv) {
    final rows = <_Row3>[
      _Row3('PV1', inv.uPv1, inv.iPv1),
      _Row3('PV2', inv.uPv2, inv.iPv2),
    ];

    return _card(
      title: 'DC',
      child: _table3(
        headers: const ['Voltage(V)', 'Current(A)', 'Power(W)'],
        rows: rows,
      ),
    );
  }

  Widget _acCard(Inverter inv) {
    final freq = inv.fac;
    final rows = <_RowAC>[
      _RowAC('L1', inv.uAc1, inv.iAc1, freq),
      _RowAC('L2', inv.uAc2, inv.iAc2, freq),
      _RowAC('L3', inv.uAc3, inv.iAc3, freq),
    ];

    return _card(
      title: 'AC',
      child: _tableAC(
        headers: const ['Voltage(V)', 'Current(A)', 'Frequency(Hz)'],
        rows: rows,
      ),
    );
  }

  Widget _generationCard(Inverter inv) {
    final dailyHours = inv.fullHour;
    final dailyYield = inv.eToday;
    return _card(
      title: 'Generation',
      child: Column(
        children: [
          _kv(
            'Daily Full Load Hours',
            dailyHours != null ? '${dailyHours.toStringAsFixed(2)} h' : '-',
          ),
          const Divider(height: 18, color: AppColors.surfaceBorder),
          _kv(
            'Daily Yield',
            dailyYield != null
                ? '${dailyYield.toStringAsFixed(1)} ${inv.eTodayStr ?? "kWh"}'
                : '-',
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          v,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
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
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _table3({required List<String> headers, required List<_Row3> rows}) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.0),
      },
      children: [
        TableRow(
          children: [
            const SizedBox(),
            ...headers.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
        ...rows.map((r) {
          final v = r.v;
          final a = r.a;
          final p = (v != null && a != null) ? (v * a) : null;
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  r.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _cell(v != null ? v.toStringAsFixed(1) : '-'),
              _cell(a != null ? a.toStringAsFixed(2) : '-'),
              _cell(p != null ? p.toStringAsFixed(0) : '-'),
            ],
          );
        }),
      ],
    );
  }

  Widget _tableAC({required List<String> headers, required List<_RowAC> rows}) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.1),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.0),
      },
      children: [
        TableRow(
          children: [
            const SizedBox(),
            ...headers.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
        ...rows.map(
          (r) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  r.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _cell(r.v != null ? r.v!.toStringAsFixed(1) : '-'),
              _cell(r.a != null ? r.a!.toStringAsFixed(2) : '-'),
              _cell(r.f != null ? r.f!.toStringAsFixed(2) : '-'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Row3 {
  final String label;
  final double? v;
  final double? a;

  const _Row3(this.label, this.v, this.a);
}

class _RowAC {
  final String label;
  final double? v;
  final double? a;
  final double? f;

  const _RowAC(this.label, this.v, this.a, this.f);
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: const Text(
        'Failed to load inverter detail. Pull to refresh.',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
