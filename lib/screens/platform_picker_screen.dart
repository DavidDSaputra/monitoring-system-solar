import 'package:flutter/material.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import 'huawei_dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PlatformPickerScreen extends StatelessWidget {
  const PlatformPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(
              children: [
                _buildSectionLabel('Tersedia'),
                const SizedBox(height: 10),
                _PlatformCard(
                  brand: _solis,
                  onTap: () => Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => const HomeScreen(),
                      transitionsBuilder: (_, anim, _, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _PlatformCard(
                  brand: _huawei,
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => const HuaweiDashboardScreen(),
                      transitionsBuilder: (_, anim, _, child) =>
                          FadeTransition(opacity: anim, child: child),
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
                    child: _PlatformCard(brand: b),
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
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/jarwinn_logo.png',
                    height: 28,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => const Text(
                      'JARWINN',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _LogoutButton(),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Pilih Platform',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.appTagline,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }

  static const _solis = _BrandInfo(
    name: 'SolisCloud',
    description: 'Solis inverter monitoring via SolisCloud API',
    tag: 'Solis',
    color: Color(0xFFF97316),
    bgColor: Color(0xFFFFF7ED),
    icon: Icons.solar_power_rounded,
    apiLabel: 'SolisCloud API v1',
  );

  static const _huawei = _BrandInfo(
    name: 'Huawei FusionSolar',
    description: 'Huawei inverter monitoring via backend API',
    tag: 'Huawei',
    color: Color(0xFF2563EB),
    bgColor: Color(0xFFEFF6FF),
    icon: Icons.memory_rounded,
    apiLabel: 'FusionSolar Northbound',
  );

  static const _comingSoon = [
    _BrandInfo(
      name: 'Deye / Solarman',
      description: 'Deye & rebranded inverter via Solarman API',
      tag: 'Deye',
      color: Color(0xFF1D4ED8),
      bgColor: Color(0xFFEFF6FF),
      icon: Icons.electrical_services_rounded,
      apiLabel: 'Solarman Business API',
    ),
    _BrandInfo(
      name: 'Growatt',
      description: 'Growatt inverter monitoring',
      tag: 'Growatt',
      color: Color(0xFF16A34A),
      bgColor: Color(0xFFF0FDF4),
      icon: Icons.bolt_rounded,
      apiLabel: 'Growatt Open API',
    ),
  ];
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            const Text(
              'Keluar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
  final String apiLabel;

  const _BrandInfo({
    required this.name,
    required this.description,
    required this.tag,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.apiLabel,
  });
}

class _PlatformCard extends StatelessWidget {
  final _BrandInfo brand;
  final VoidCallback? onTap;

  const _PlatformCard({required this.brand, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = onTap != null;
    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? brand.color.withValues(alpha: 0.3)
                  : AppColors.surfaceBorder,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: brand.color.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Brand icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: brand.bgColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(brand.icon, color: brand.color, size: 24),
              ),
              const SizedBox(width: 14),

              // Info
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
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
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: brand.bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        brand.apiLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: brand.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Icon(
                isActive
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline_rounded,
                size: 16,
                color: isActive ? brand.color : AppColors.textTertiary,
              ),
            ],
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
        color: isActive
            ? AppColors.online.withValues(alpha: 0.12)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Segera',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isActive ? AppColors.online : AppColors.textTertiary,
        ),
      ),
    );
  }
}
