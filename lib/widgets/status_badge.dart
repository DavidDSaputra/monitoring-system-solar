import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double size;
  final bool showLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.size = 10,
    this.showLabel = true,
  });

  Color get _color {
    switch (status.toLowerCase()) {
      case 'online':
        return AppColors.online;
      case 'alarm':
        return AppColors.alarm;
      case 'offline':
        return AppColors.offline;
      default:
        return AppColors.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: _color, size: size),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: _color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulseDot({required this.color, required this.size});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.color == AppColors.online) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: widget.color == AppColors.online
                ? [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: _animation.value * 0.6,
                      ),
                      blurRadius: widget.size * 2,
                      spreadRadius: widget.size * 0.3 * _animation.value,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
