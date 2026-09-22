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
  static const Color _navSurface = Colors.white;
  static const Color _navActive = Color(0xFFF97316); // JARWINN orange
  static const Color _navMuted = Color(0xFF475569);
  static const Color _navLabelMuted = Color(0xFF64748B);

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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _navSurface,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
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
                      const Expanded(child: SizedBox.shrink()),
                      _navItem(
                        3,
                        Icons.build_rounded,
                        Icons.build_outlined,
                        'Service',
                      ),
                      _navItem(
                        4,
                        Icons.person_rounded,
                        Icons.person_outline,
                        'Me',
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: _centerNavItem(
                  2,
                  Icons.bar_chart_rounded,
                  Icons.bar_chart_outlined,
                  'Overview',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 58,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isActive ? 38 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _navActive,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? activeIcon : icon,
                      size: 21,
                      color: isActive ? _navActive : _navMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isActive ? _navActive : _navLabelMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerNavItem(
    int index,
    IconData activeIcon,
    IconData icon,
    String label,
  ) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: _navActive,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _navActive.withValues(alpha: isActive ? 0.34 : 0.22),
              blurRadius: isActive ? 22 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, size: 23, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
