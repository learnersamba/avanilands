import 'package:flutter/material.dart';

import '../theme.dart';

/// The Avanilands mark: a hill line on a round badge (same drawing as the
/// website logo). Set [onDark] for dark backgrounds, where the badge is a
/// faint white circle instead of forest green.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    excludeSemantics: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(onDark: onDark),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.onDark});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32;
    Offset p(double x, double y) => Offset(x * unit, y * unit);
    canvas.drawCircle(
      p(16, 16),
      16 * unit,
      Paint()..color = onDark ? const Color(0x1AFFFFFF) : BrandColors.forest,
    );
    final hill = Path()
      ..moveTo(5 * unit, 22 * unit)
      ..lineTo(12 * unit, 13 * unit)
      ..lineTo(16 * unit, 18 * unit)
      ..lineTo(20 * unit, 11 * unit)
      ..lineTo(27 * unit, 22 * unit)
      ..close();
    canvas.drawPath(hill, Paint()..color = BrandColors.sand);
    canvas.drawLine(
      p(5, 22),
      p(27, 22),
      Paint()
        ..color = const Color(0xFFEFE3C8)
        ..strokeWidth = 1.5 * unit,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onDark != onDark;
}
