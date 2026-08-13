import 'package:flutter/material.dart';

/// Dims the camera preview except for a document-shaped window, and draws
/// corner brackets around it.
///
/// The frame is guidance, not a crop — the photo is always taken at full
/// resolution and sent whole. Cropping to the window would throw away pixels
/// the server may need, and a user who framed slightly wide would lose the
/// edge of their receipt with no way to tell.
class CaptureFrameOverlay extends StatelessWidget {
  const CaptureFrameOverlay({
    super.key,
    required this.aspectRatio,
    this.margin = 20.0,
  });

  /// Width divided by height of the document being photographed.
  final double aspectRatio;

  /// Gap between the window and the screen edge, at the window's widest.
  final double margin;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FramePainter(aspectRatio: aspectRatio, margin: margin),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.aspectRatio, required this.margin});

  final double aspectRatio;
  final double margin;

  static const _cornerLength = 28.0;
  static const _cornerWidth = 4.0;
  static const _radius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final window = _windowRect(size);
    final rounded = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );

    // Even-odd fill turns the window into a hole in the dim layer, so the
    // preview shows through it at full brightness.
    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rounded)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.6));

    final bracket = Paint()
      ..color = Colors.white
      ..strokeWidth = _cornerWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Corners only. A full outline reads as a crop boundary and invites people
    // to line the document up exactly, which is slower and no more accurate.
    for (final (corner, dx, dy) in [
      (window.topLeft, 1.0, 1.0),
      (window.topRight, -1.0, 1.0),
      (window.bottomLeft, 1.0, -1.0),
      (window.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(
        corner.translate(dx * _radius, 0),
        corner.translate(dx * _cornerLength, 0),
        bracket,
      );
      canvas.drawLine(
        corner.translate(0, dy * _radius),
        corner.translate(0, dy * _cornerLength),
        bracket,
      );
    }
  }

  /// The largest rectangle of [aspectRatio] that fits inside [size] with
  /// [margin] to spare.
  Rect _windowRect(Size size) {
    final available = Size(size.width - margin * 2, size.height - margin * 2);

    var width = available.width;
    var height = width / aspectRatio;
    if (height > available.height) {
      height = available.height;
      width = height * aspectRatio;
    }

    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.aspectRatio != aspectRatio || old.margin != margin;
}
