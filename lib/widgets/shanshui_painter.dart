import 'dart:math';
import 'package:flutter/material.dart';

/// Paints an abstract Shanshui-inspired ink-wash landscape entirely on
/// device — layered misty mountain silhouettes, a sun/moon circle, and a
/// scattering of "brush stroke" accents. Fully deterministic from [seed], so
/// the same poem always produces the same image, but different poems look
/// different. No network calls, no API cost, works offline, always
/// succeeds.
class ShanshuiPainter extends CustomPainter {
  final int seed;
  final Color inkColor;
  final Color mistColor;
  final Color accentColor;

  ShanshuiPainter({
    required this.seed,
    this.inkColor = const Color(0xFF2A2A32),
    this.mistColor = const Color(0xFFB8C4C2),
    this.accentColor = const Color(0xFFC9A227),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final width = size.width;
    final height = size.height;

    // Soft gradient sky/mist background.
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          mistColor.withOpacity(0.35),
          mistColor.withOpacity(0.12),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Sun/moon circle — position and size vary by seed.
    final circleCenter = Offset(
      width * (0.2 + rng.nextDouble() * 0.6),
      height * (0.15 + rng.nextDouble() * 0.2),
    );
    final circleRadius = width * (0.06 + rng.nextDouble() * 0.05);
    final circlePaint = Paint()..color = accentColor.withOpacity(0.55);
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);

    // 3-4 layered mountain silhouettes, back to front, each lighter/further
    // back than the last, in the classic Shanshui "receding peaks" style.
    final layerCount = 3 + rng.nextInt(2);
    for (int layer = 0; layer < layerCount; layer++) {
      final depthFactor = layer / layerCount; // 0 = furthest back
      final baseY = height * (0.45 + depthFactor * 0.18);
      final peakHeight = height * (0.30 - depthFactor * 0.12);
      final opacity = 0.85 - depthFactor * 0.45;

      final path = Path()..moveTo(0, height);
      path.lineTo(0, baseY);

      // Build a jagged-but-smooth mountain ridge using seeded peaks.
      const segments = 6;
      double x = 0;
      final segWidth = width / segments;
      for (int i = 0; i <= segments; i++) {
        final peakVariance = (rng.nextDouble() - 0.5) * peakHeight;
        final y = baseY - (rng.nextDouble() * peakHeight * 0.6) - peakVariance.abs();
        path.lineTo(x, y.clamp(height * 0.05, height));
        x += segWidth;
      }
      path.lineTo(width, baseY);
      path.lineTo(width, height);
      path.close();

      final mountainPaint = Paint()..color = inkColor.withOpacity(opacity.clamp(0.15, 0.9));
      canvas.drawPath(path, mountainPaint);
    }

    // A handful of loose "brush stroke" accents (reeds/grass gestures) near
    // the bottom, for texture.
    final strokePaint = Paint()
      ..color = inkColor.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final strokeCount = 5 + rng.nextInt(4);
    for (int i = 0; i < strokeCount; i++) {
      final startX = rng.nextDouble() * width;
      final startY = height * (0.85 + rng.nextDouble() * 0.1);
      final endX = startX + (rng.nextDouble() - 0.5) * width * 0.08;
      final endY = startY - height * (0.04 + rng.nextDouble() * 0.06);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ShanshuiPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.mistColor != mistColor ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Convenience widget wrapping [ShanshuiPainter] with a fixed aspect ratio,
/// ready to drop into any layout.
class ShanshuiArt extends StatelessWidget {
  final int seed;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  const ShanshuiArt({
    super.key,
    required this.seed,
    this.aspectRatio = 16 / 10,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: ShanshuiPainter(seed: seed),
      child: AspectRatio(aspectRatio: aspectRatio, child: const SizedBox.expand()),
    );

    if (borderRadius == null) return painter;
    return ClipRRect(borderRadius: borderRadius!, child: painter);
  }
}