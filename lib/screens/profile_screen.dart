import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'platform_picker_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeroHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('API Connection'),
                  const SizedBox(height: 8),
                  _buildConnectionCard(context),
                  const SizedBox(height: 20),
                  _buildSectionLabel('System'),
                  const SizedBox(height: 8),
                  _buildSystemCard(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('About'),
                  const SizedBox(height: 8),
                  _buildAboutCard(context),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Akun'),
                  const SizedBox(height: 8),
                  _buildAccountCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'J',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        const Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants.appTagline,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildStatusChip(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildHeroStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF86EFAC),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'API Connected',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Row(
      children: [
        _heroStat('Platform', 'SolisCloud'),
        _heroDivider(),
        _heroStat('Version', AppConstants.appVersion),
        _heroDivider(),
        _heroStat('Protocol', 'HMAC-SHA1'),
      ],
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _buildConnectionCard(BuildContext context) {
    return _card(
      child: Column(
        children: [
          _listRow(
            icon: Icons.cloud_done_rounded,
            iconColor: AppColors.online,
            iconBg: const Color(0xFFD1FAE5),
            title: 'Base URL',
            trailing: Text(
              AppConstants.baseUrl,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.vpn_key_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFFFF7ED),
            title: 'API Key ID',
            trailing: GestureDetector(
              onTap: () => _copyToClipboard(context, 'API Key ID copied'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '••••••••••••',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF8B5CF6),
            iconBg: const Color(0xFFEDE9FE),
            title: 'Auth Method',
            trailing: const Text(
              'HMAC-SHA1',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.speed_rounded,
            iconColor: AppColors.warning,
            iconBg: const Color(0xFFFEF3C7),
            title: 'Rate Limit',
            trailing: Text(
              '${AppConstants.maxRequestsPerWindow} req / 5s',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard() {
    return _card(
      child: Column(
        children: [
          _listRow(
            icon: Icons.solar_power_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFFFF7ED),
            title: 'Monitored System',
            trailing: const Text(
              'SolisCloud',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.refresh_rounded,
            iconColor: const Color(0xFF0EA5E9),
            iconBg: const Color(0xFFE0F2FE),
            title: 'Auto Refresh',
            trailing: const Text(
              'Every 30s',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.data_usage_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            title: 'Data Points',
            trailing: const Text(
              'Live',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return _card(
      child: Column(
        children: [
          _listRow(
            icon: Icons.info_outline_rounded,
            iconColor: const Color(0xFF0EA5E9),
            iconBg: const Color(0xFFE0F2FE),
            title: 'App Version',
            trailing: Text(
              'v${AppConstants.appVersion}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.business_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFFFF7ED),
            title: 'Developer',
            trailing: const Text(
              'JARWINN',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.gavel_rounded,
            iconColor: AppColors.textTertiary,
            iconBg: AppColors.surfaceLight,
            title: 'Licenses',
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return _card(
      child: Column(
        children: [
          _listRow(
            icon: Icons.swap_horiz_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFFFF7ED),
            title: 'Ganti Platform',
            onTap: () => Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (_, _, _) => const PlatformPickerScreen(),
                transitionsBuilder: (_, anim, _, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              ),
            ),
          ),
          _divider(),
          _listRow(
            icon: Icons.logout_rounded,
            iconColor: AppColors.alarm,
            iconBg: const Color(0xFFFEF2F2),
            title: 'Keluar',
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari aplikasi?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => const LoginScreen(),
                  transitionsBuilder: (_, anim, _, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 350),
                ),
                (_) => false,
              );
            },
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: AppColors.alarm,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: child,
    );
  }

  Widget _listRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ?trailing,
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.surfaceBorder,
      indent: 60,
    );
  }

  void _copyToClipboard(BuildContext context, String message) {
    Clipboard.setData(const ClipboardData(text: '••••••••••••'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
