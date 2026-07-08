import 'dart:math';
import 'package:flutter/material.dart';

/// Paints an abstract Shanshui-inspired ink-wash landscape entirely on
/// device — layered misty mountain silhouettes, a sun/moon circle, and a
/// scattering of "brush stroke" accents. Fully deterministic from [seed], so
/// the same poem always produces the same image, but different poems
/// produce visibly different compositions, palettes, and layouts. No
/// network calls, no API cost, works offline, always succeeds.
class ShanshuiPainter extends CustomPainter {
  final int seed;

  const ShanshuiPainter({required this.seed});

  // A handful of distinct ink-wash color palettes (ink, mist, accent). The
  // seed picks one, so different poems don't just vary in shape but in
  // overall mood/color too.
  static const List<List<Color>> _palettes = [
    [Color(0xFF2A2A32), Color(0xFFB8C4C2), Color(0xFFC9A227)], // classic ink/gold
    [Color(0xFF1F2E2B), Color(0xFF9FBFB8), Color(0xFFD98F4E)], // jade/amber dusk
    [Color(0xFF262038), Color(0xFFB3A9C7), Color(0xFFE0C36A)], // violet twilight
    [Color(0xFF1C2B33), Color(0xFF8FB0BE), Color(0xFFE8E0C9)], // slate/pale moon
    [Color(0xFF2E2420), Color(0xFFC7B199), Color(0xFFB33A3A)], // autumn crimson
    [Color(0xFF1A2A24), Color(0xFFA8C4B0), Color(0xFFEFD9A0)], // deep pine/gold
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final width = size.width;
    final height = size.height;

    final palette = _palettes[seed.abs() % _palettes.length];
    final inkColor = palette[0];
    final mistColor = palette[1];
    final accentColor = palette[2];

    // Randomly mirror the whole composition horizontally for extra layout
    // variety — same palette/seed elsewhere would otherwise always compose
    // left-to-right identically.
    final mirror = rng.nextBool();
    canvas.save();
    if (mirror) {
      canvas.translate(width, 0);
      canvas.scale(-1, 1);
    }

    // Background gradient direction also varies (top-down vs diagonal).
    final diagonalSky = rng.nextBool();
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: diagonalSky ? Alignment.topLeft : Alignment.topCenter,
        end: diagonalSky ? Alignment.bottomRight : Alignment.bottomCenter,
        colors: [
          mistColor.withOpacity(0.35),
          mistColor.withOpacity(0.12),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Sun/moon circle — position, size, and softness vary by seed.
    final circleCenter = Offset(
      width * (0.15 + rng.nextDouble() * 0.7),
      height * (0.12 + rng.nextDouble() * 0.22),
    );
    final circleRadius = width * (0.05 + rng.nextDouble() * 0.07);
    final circlePaint = Paint()..color = accentColor.withOpacity(0.4 + rng.nextDouble() * 0.35);
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);
    // Soft halo around it, sometimes.
    if (rng.nextBool()) {
      final haloPaint = Paint()..color = accentColor.withOpacity(0.15);
      canvas.drawCircle(circleCenter, circleRadius * 1.8, haloPaint);
    }

    // 2-5 layered mountain silhouettes, back to front, each lighter/further
    // back than the last, in the classic Shanshui "receding peaks" style.
    // Layer count itself varies more now (2-5, was fixed at 3-4).
    final layerCount = 2 + rng.nextInt(4);
    for (int layer = 0; layer < layerCount; layer++) {
      final depthFactor = layer / layerCount; // 0 = furthest back
      final baseY = height * (0.42 + depthFactor * 0.20);
      final peakHeight = height * (0.32 - depthFactor * 0.13);
      final opacity = 0.88 - depthFactor * 0.48;
      final jaggedness = 0.3 + rng.nextDouble() * 0.5; // varies per layer

      final path = Path()..moveTo(0, height);
      path.lineTo(0, baseY);

      final segments = 4 + rng.nextInt(4); // 4-7 segments, more shape variety
      double x = 0;
      final segWidth = width / segments;
      for (int i = 0; i <= segments; i++) {
        final peakVariance = (rng.nextDouble() - 0.5) * peakHeight * jaggedness;
        final y = baseY - (rng.nextDouble() * peakHeight * 0.6) - peakVariance.abs();
        path.lineTo(x, y.clamp(height * 0.05, height));
        x += segWidth;
      }
      path.lineTo(width, baseY);
      path.lineTo(width, height);
      path.close();

      final mountainPaint = Paint()..color = inkColor.withOpacity(opacity.clamp(0.15, 0.92));
      canvas.drawPath(path, mountainPaint);
    }

    // A handful of loose "brush stroke" accents (reeds/grass gestures) near
    // the bottom, for texture. Count and thickness vary per seed.
    final strokeWidth = 1.0 + rng.nextDouble() * 1.5;
    final strokePaint = Paint()
      ..color = inkColor.withOpacity(0.55)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final strokeCount = 3 + rng.nextInt(7); // 3-9, more range than before
    for (int i = 0; i < strokeCount; i++) {
      final startX = rng.nextDouble() * width;
      final startY = height * (0.82 + rng.nextDouble() * 0.14);
      final endX = startX + (rng.nextDouble() - 0.5) * width * 0.1;
      final endY = startY - height * (0.03 + rng.nextDouble() * 0.08);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), strokePaint);
    }

    // Occasionally add a simple distant "pagoda" silhouette (small triangle
    // + short vertical) for an extra point of visual distinction — roughly
    // 1 in 3 compositions.
    if (rng.nextDouble() < 0.33) {
      final pagodaX = width * (0.2 + rng.nextDouble() * 0.6);
      final pagodaBaseY = height * (0.55 + rng.nextDouble() * 0.15);
      final pagodaHeight = height * 0.09;
      final pagodaPaint = Paint()..color = inkColor.withOpacity(0.7);
      final pagodaPath = Path()
        ..moveTo(pagodaX - pagodaHeight * 0.35, pagodaBaseY)
        ..lineTo(pagodaX, pagodaBaseY - pagodaHeight)
        ..lineTo(pagodaX + pagodaHeight * 0.35, pagodaBaseY)
        ..close();
      canvas.drawPath(pagodaPath, pagodaPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShanshuiPainter oldDelegate) {
    return oldDelegate.seed != seed;
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