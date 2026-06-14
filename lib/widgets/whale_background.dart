import 'dart:math' as math;
import 'package:flutter/material.dart';

class WhaleNavBarWrapper extends StatefulWidget {
  final Widget child;

  const WhaleNavBarWrapper({
    super.key,
    required this.child,
  });

  @override
  State<WhaleNavBarWrapper> createState() => _WhaleNavBarWrapperState();
}

class _WhaleNavBarWrapperState extends State<WhaleNavBarWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final waveColor = accent.withOpacity(0.12);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Wavy Background inside Nav
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter: WavePainter(
                    animationValue: _waveController.value,
                    color: waveColor,
                  ),
                );
              },
            ),
          ),
          // Nav Bar Content
          widget.child,
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final yOffset = size.height * 0.5;

    path.moveTo(0, size.height);
    path.lineTo(0, yOffset);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        yOffset + math.sin((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 6,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);
    path2.lineTo(0, yOffset + 3);
    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(
        i,
        yOffset + 3 + math.cos((i / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 4,
      );
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}
