import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/monitoring_health_service.dart';
import 'growatt_dashboard_screen.dart';
import 'huawei_dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

const _pickerBg = Color(0xFFFFF8F2);
const _pickerInk = Color(0xFF111827);
const _pickerMuted = Color(0xFF667085);
const _pickerOrange = Color(0xFFF97316);
const _pickerOrangeSoft = Color(0xFFFFF1E6);
const _pickerBorder = Color(0xFFF4D6BF);

class PlatformPickerScreen extends StatefulWidget {
  const PlatformPickerScreen({super.key});

  @override
  State<PlatformPickerScreen> createState() => _PlatformPickerScreenState();
}

class _PlatformPickerScreenState extends State<PlatformPickerScreen> {
  final MonitoringHealthService _healthService = MonitoringHealthService();
  late Future<MonitoringHealth> _healthFuture;

  @override
  void initState() {
    super.initState();
    _healthFuture = _healthService.getHealth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pickerBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
            sliver: SliverList.list(
              children: [
                _buildHealthCard(),
                const SizedBox(height: 16),
                _buildSectionLabel('Tersedia'),
                const SizedBox(height: 10),
                _PlatformCard(
                  brand: _solis,
                  delay: const Duration(milliseconds: 40),
                  onTap: () => Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => const HomeScreen(),
                      transitionsBuilder: _pageTransition,
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _PlatformCard(
                  brand: _huawei,
                  delay: const Duration(milliseconds: 90),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => const HuaweiDashboardScreen(),
                      transitionsBuilder: _pageTransition,
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _PlatformCard(
                  brand: _growatt,
                  delay: const Duration(milliseconds: 140),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => const GrowattDashboardScreen(),
                      transitionsBuilder: _pageTransition,
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel('Segera Hadir'),
                const SizedBox(height: 10),
                ..._comingSoon.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlatformCard(
                      brand: b,
                      delay: const Duration(milliseconds: 190),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _pickerBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _pickerOrangeSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _pickerBorder),
                    ),
                    child: Image.asset(
                      'assets/images/jarwinn_logo.png',
                      width: 112,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'JARWINN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _pickerInk,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _LogoutButton(),
                ],
              ),
              const SizedBox(height: 22),
              _heroChip(),
              const SizedBox(height: 12),
              const Text(
                'Pilih platform',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _pickerInk,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appTagline,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _pickerMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _pickerOrangeSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _pickerBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_view_rounded, color: _pickerOrange, size: 15),
          SizedBox(width: 6),
          Text(
            'Monitoring solar',
            style: TextStyle(
              color: _pickerOrange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: _pickerMuted,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildHealthCard() {
    return FutureBuilder<MonitoringHealth>(
      future: _healthFuture,
      builder: (context, snapshot) {
        final health = snapshot.data;
        final failed = snapshot.hasError;
        final color = failed ? _pickerMuted : _pickerOrange;
        final title = failed
            ? 'Connection check'
            : 'System ${health?.status.toUpperCase() ?? 'checking'}';
        final subtitle = failed
            ? 'Backend belum tersambung'
            : health?.baseUrl ?? 'Checking provider status';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _pickerBorder),
            boxShadow: [
              BoxShadow(
                color: _pickerOrange.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  failed ? Icons.cloud_off_rounded : Icons.cloud_done_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _pickerInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _pickerMuted, fontSize: 11),
                    ),
                    if (health != null) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _providerPill('Solis', health.providers['solis']),
                          _providerPill('Huawei', health.providers['huawei']),
                          _providerPill('Growatt', health.providers['growatt']),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh status',
                onPressed: () => setState(() {
                  _healthFuture = _healthService.getHealth();
                }),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: _pickerOrange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _providerPill(String label, ProviderHealth? provider) {
    final status = provider?.status ?? 'unknown';
    final usable = status == 'ok' || status == 'stale';
    final color = usable ? _pickerOrange : _pickerMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: usable ? _pickerOrangeSoft : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $status',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Widget _pageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  static const _solis = _BrandInfo(
    name: 'SolisCloud',
    description: 'Solis inverter monitoring via SolisCloud API',
    tag: 'Solis',
    color: _pickerOrange,
    bgColor: _pickerOrangeSoft,
    icon: Icons.solar_power_rounded,
    logoAsset: 'assets/images/solis-logo.png',
    apiLabel: 'SolisCloud API v1',
  );

  static const _huawei = _BrandInfo(
    name: 'Huawei FusionSolar',
    description: 'Huawei inverter monitoring via backend API',
    tag: 'Huawei',
    color: _pickerOrange,
    bgColor: _pickerOrangeSoft,
    icon: Icons.memory_rounded,
    logoAsset: 'assets/images/fusionsolar-logo.jpg',
    apiLabel: 'FusionSolar Northbound',
  );

  static const _growatt = _BrandInfo(
    name: 'Growatt',
    description: 'Growatt inverter monitoring via backend API',
    tag: 'Growatt',
    color: _pickerOrange,
    bgColor: _pickerOrangeSoft,
    icon: Icons.bolt_rounded,
    logoAsset: 'assets/images/Growatt-logo.png',
    apiLabel: 'Growatt Open API',
  );

  static const _comingSoon = [
    _BrandInfo(
      name: 'Deye / Solarman',
      description: 'Deye & rebranded inverter via Solarman API',
      tag: 'Deye',
      color: _pickerMuted,
      bgColor: Color(0xFFF3F4F6),
      icon: Icons.electrical_services_rounded,
      apiLabel: 'Solarman Business API',
    ),
  ];

  @override
  void dispose() {
    _healthService.dispose();
    super.dispose();
  }
}

// ─── Logout button ─────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AuthService.logout();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const LoginScreen(),
            transitionsBuilder: (_, anim, _, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _pickerOrangeSoft,
          shape: BoxShape.circle,
          border: Border.all(color: _pickerBorder),
        ),
        child: const Icon(Icons.logout_rounded, size: 18, color: _pickerOrange),
      ),
    );
  }
}

// ─── Platform card ──────────────────────────────────────────────────────

class _BrandInfo {
  final String name;
  final String description;
  final String tag;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String? logoAsset;
  final String apiLabel;

  const _BrandInfo({
    required this.name,
    required this.description,
    required this.tag,
    required this.color,
    required this.bgColor,
    required this.icon,
    this.logoAsset,
    required this.apiLabel,
  });
}

class _PlatformCard extends StatefulWidget {
  final _BrandInfo brand;
  final VoidCallback? onTap;
  final Duration delay;

  const _PlatformCard({
    required this.brand,
    this.onTap,
    this.delay = Duration.zero,
  });

  @override
  State<_PlatformCard> createState() => _PlatformCardState();
}

class _PlatformCardState extends State<_PlatformCard> {
  bool _pressed = false;
  bool _hovered = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.brand;
    final isActive = widget.onTap != null;
    final lift = _hovered && isActive;

    return AnimatedOpacity(
      opacity: _visible ? (isActive ? 1.0 : 0.62) : 0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : (lift ? 1.01 : 1),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: isActive
                    ? (_) => setState(() => _pressed = true)
                    : null,
                onTapCancel: isActive
                    ? () => setState(() => _pressed = false)
                    : null,
                onTapUp: isActive
                    ? (_) => setState(() => _pressed = false)
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive ? _pickerBorder : AppColors.surfaceBorder,
                      width: 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: _pickerOrange.withValues(
                                alpha: lift ? 0.16 : 0.08,
                              ),
                              blurRadius: lift ? 22 : 14,
                              offset: Offset(0, lift ? 8 : 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 14, 14, 15),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? brand.bgColor
                                      : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: brand.color.withValues(
                                      alpha: isActive ? 0.14 : 0.06,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: brand.logoAsset == null
                                    ? Icon(
                                        brand.icon,
                                        color: brand.color,
                                        size: 24,
                                      )
                                    : Image.asset(
                                        brand.logoAsset!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => Icon(
                                          brand.icon,
                                          color: brand.color,
                                          size: 24,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            brand.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: _pickerInk,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _StatusBadge(isActive: isActive),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      brand.description,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _pickerMuted,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _MiniTag(
                                          label: brand.apiLabel,
                                          color: brand.color,
                                          fill: brand.bgColor,
                                        ),
                                        _MiniTag(
                                          label: brand.tag,
                                          color: _pickerMuted,
                                          fill: const Color(0xFFF3F4F6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? _pickerOrangeSoft
                                      : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.arrow_forward_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 18,
                                  color: isActive
                                      ? _pickerOrange
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? _pickerOrangeSoft : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Segera',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? _pickerOrange : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color fill;

  const _MiniTag({
    required this.label,
    required this.color,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
