import 'package:flutter/material.dart';

/// A faint diagonal hatch, for the one card per screen that should read as a
/// "featured" panel rather than a plain data card — the reference dashboard
/// uses the same device behind its live camera tile and its dark emphasis
/// tile. Painted, not an asset, so it recolours for free with the intent
/// colour passed in and costs nothing to ship.
class AppHatchPattern extends StatelessWidget {
  const AppHatchPattern({
    super.key,
    required this.color,
    this.spacing = 10,
    this.strokeWidth = 1,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _HatchPainter(
          color: color,
          spacing: spacing,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({
    required this.color,
    required this.spacing,
    required this.strokeWidth,
  });

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // 45-degree lines across the whole box, clipped to its bounds — cheapest
    // way to get an even hatch regardless of the card's size.
    final total = size.width + size.height;
    for (double x = -size.height; x < total; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) =>
      old.color != color || old.spacing != spacing;
}
