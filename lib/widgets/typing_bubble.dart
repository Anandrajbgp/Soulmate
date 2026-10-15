import 'package:flutter/material.dart';

/// WhatsApp-style animated 3-dot bouncing typing indicator.
class TypingBubble extends StatefulWidget {
  final bool isDark;

  const TypingBubble({super.key, required this.isDark});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF202C33) : Colors.white;
    final dotColor = widget.isDark ? const Color(0xFF8696A0) : Colors.grey;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0.0, dotColor),
            const SizedBox(width: 5),
            _buildDot(0.2, dotColor),
            const SizedBox(width: 5),
            _buildDot(0.4, dotColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(double delay, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = (_controller.value + delay) % 1.0;
        final bounce = val < 0.5 ? val * 2 : (1.0 - val) * 2;
        return Transform.translate(
          offset: Offset(0, -bounce * 6),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4 + (bounce * 0.6)),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
