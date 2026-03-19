import 'package:flutter/material.dart';

/// A white box widget with a slanted (parallelogram) shape and rounded corners.
class TicketBox extends StatelessWidget {
  final Widget child;

  /// The amount of horizontal slant (pixels)
  final double slant;

  /// Outer border radius of the box
  final double borderRadius;

  final Color color;
  final List<BoxShadow>? shadows;

  const TicketBox({
    super.key,
    required this.child,
    this.slant = 12,
    this.borderRadius = 16,
    this.color = Colors.white,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SlantedBoxPainter(
        color: color,
        slant: slant,
        borderRadius: borderRadius,
        shadows:
            shadows ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: ClipPath(
        clipper: _SlantedBoxClipper(slant: slant, borderRadius: borderRadius),
        child: child,
      ),
    );
  }
}

class _SlantedBoxPainter extends CustomPainter {
  final Color color;
  final double slant;
  final double borderRadius;
  final List<BoxShadow> shadows;

  _SlantedBoxPainter({
    required this.color,
    required this.slant,
    required this.borderRadius,
    required this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    for (final shadow in shadows) {
      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
      canvas.drawPath(path.shift(shadow.offset), shadowPaint);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final dx = slant;
    final ratio = dx / h;

    final path = Path();

    // Top edge
    path.moveTo(dx + r, 0);
    path.lineTo(w - r, 0);

    // Top-right corner
    path.quadraticBezierTo(w, 0, w - r * ratio, r);

    // Right slanted edge
    path.lineTo(w - dx + r * ratio, h - r);

    // Bottom-right corner
    path.quadraticBezierTo(w - dx, h, w - dx - r, h);

    // Bottom edge
    path.lineTo(r, h);

    // Bottom-left corner
    path.quadraticBezierTo(0, h, r * ratio, h - r);

    // Left slanted edge
    path.lineTo(dx - r * ratio, r);

    // Top-left corner
    path.quadraticBezierTo(dx, 0, dx + r, 0);

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_SlantedBoxPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.slant != slant ||
      oldDelegate.borderRadius != borderRadius;
}

class _SlantedBoxClipper extends CustomClipper<Path> {
  final double slant;
  final double borderRadius;

  _SlantedBoxClipper({required this.slant, required this.borderRadius});

  @override
  Path getClip(Size size) {
    return _SlantedBoxPainter(
      color: Colors.transparent,
      slant: slant,
      borderRadius: borderRadius,
      shadows: [],
    )._buildPath(size);
  }

  @override
  bool shouldReclip(_SlantedBoxClipper oldClipper) =>
      oldClipper.slant != slant || oldClipper.borderRadius != borderRadius;
}