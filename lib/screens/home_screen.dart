import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'events_screen.dart';
import 'overview_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const Color _shellBackground = Color(0xFFF8FAFC);
  static const Color _navSurface = Color(0xF2FFFFFF);
  static const Color _navBorder = Color(0xFFE2E8F0);
  static const Color _navActive = Color(0xFFF97316); // JARWINN orange
  static const Color _navMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _shellBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DashboardScreen(),
          const EventsScreen(),
          const OverviewScreen(),
          _buildPlaceholderTab('Service', Icons.build_outlined),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _navSurface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _navBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  0,
                  Icons.solar_power_rounded,
                  Icons.solar_power_outlined,
                  'Plants',
                ),
                _navItem(
                  1,
                  Icons.notifications_rounded,
                  Icons.notifications_outlined,
                  'Events',
                ),
                _navItem(
                  2,
                  Icons.bar_chart_rounded,
                  Icons.bar_chart_outlined,
                  'Overview',
                ),
                _navItem(
                  3,
                  Icons.build_rounded,
                  Icons.build_outlined,
                  'Service',
                ),
                _navItem(4, Icons.person_rounded, Icons.person_outline, 'Me'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isActive ? _navActive : Colors.transparent,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _navActive.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive ? Colors.white : _navMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _navActive : _navMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Scaffold(
      backgroundColor: _shellBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: _navMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon',
              style: TextStyle(fontSize: 13, color: _navMuted),
            ),
          ],
        ),
      ),
    );
  }
}
