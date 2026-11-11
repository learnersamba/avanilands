import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A painted countryside: sky, hills, a tree line, a ploughed field and a
/// modern house. Drawn instead of a photo so it stays sharp at any size and
/// costs nothing to load. Used behind the dashboard greeting.
class LandscapePainter extends CustomPainter {
  const LandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.6;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD5E8EE), Color(0xFFF5EFD9)],
        ).createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
    final sun = Offset(w * 0.7, h * 0.15);
    canvas.drawCircle(
      sun,
      h * 0.9,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xE6FFF3D2), Color(0x00FFF3D2)],
        ).createShader(Rect.fromCircle(center: sun, radius: h * 0.9)),
    );

    _hills(canvas, w, horizon - h * 0.03, h * 0.17, const Color(0xFFB9D2C2), 0);
    _hills(
      canvas,
      w,
      horizon + h * 0.01,
      h * 0.1,
      const Color(0xFF94BD95),
      1.7,
    );

    final treeLine = Paint()..color = const Color(0xFF55875A);
    for (var x = w * 0.2; x < w; x += h * 0.045) {
      final r = h * (0.022 + 0.014 * (math.sin(x * 0.37) + 1) / 2);
      canvas.drawCircle(Offset(x, horizon - r * 0.3), r, treeLine);
    }

    final field = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      field,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA8CB72), Color(0xFF6A9C43)],
        ).createShader(field),
    );
    canvas.save();
    canvas.clipRect(field);
    final vanish = Offset(w * 0.7, horizon - h * 0.06);
    final rows = Paint()
      ..color = const Color(0x1C2F5A22)
      ..strokeWidth = 2;
    for (var x = -w; x < w * 2; x += h * 0.11) {
      canvas.drawLine(vanish, Offset(x, h), rows);
    }
    canvas.restore();

    _tree(canvas, Offset(w * 0.64, horizon + h * 0.04), h * 0.24);
    _house(canvas, Offset(w * 0.8, horizon + h * 0.03), h);
    _tree(canvas, Offset(w * 0.93, horizon + h * 0.06), h * 0.2);

    // A large canopy hanging into the top-right corner.
    final dark = Paint()..color = const Color(0xFF3D6C39);
    final light = Paint()..color = const Color(0xFF5B8E49);
    for (var i = 0; i < 9; i++) {
      final a = i / 8 * math.pi;
      final centre = Offset(
        w - h * 0.08 + math.cos(a) * h * 0.36,
        -h * 0.06 + math.sin(a) * h * 0.17,
      );
      canvas.drawCircle(centre, h * 0.12, i.isEven ? dark : light);
    }
  }

  void _hills(
    Canvas canvas,
    double w,
    double base,
    double height,
    Color color,
    double phase,
  ) {
    final path = Path()..moveTo(0, base);
    for (var x = 0.0; x <= w + 8; x += 8) {
      final wave = 0.5 + 0.5 * math.sin(x / w * math.pi * 2.2 + phase);
      final detail = 0.6 + 0.4 * math.sin(x / w * math.pi * 5 + phase * 2);
      path.lineTo(x, base - height * wave * detail);
    }
    path
      ..lineTo(w + 8, base + height)
      ..lineTo(0, base + height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _tree(Canvas canvas, Offset ground, double size) {
    canvas.drawRect(
      Rect.fromCenter(
        center: ground.translate(0, -size * 0.2),
        width: size * 0.08,
        height: size * 0.42,
      ),
      Paint()..color = const Color(0xFF6B4E33),
    );
    final dark = Paint()..color = const Color(0xFF3F7039);
    final light = Paint()..color = const Color(0xFF5E9449);
    canvas
      ..drawCircle(
        ground.translate(-size * 0.17, -size * 0.5),
        size * 0.24,
        dark,
      )
      ..drawCircle(
        ground.translate(size * 0.17, -size * 0.52),
        size * 0.24,
        dark,
      )
      ..drawCircle(ground.translate(0, -size * 0.72), size * 0.27, light);
  }

  void _house(Canvas canvas, Offset ground, double h) {
    final s = h / 200; // Drawn for a 200 px tall banner.
    Rect box(double left, double top, double width, double height) =>
        Rect.fromLTWH(
          ground.dx + left * s,
          ground.dy + top * s,
          width * s,
          height * s,
        );
    Offset at(double x, double y) => ground.translate(x * s, y * s);
    final wall = Paint()..color = const Color(0xFFF7F2E7);
    final shade = Paint()..color = const Color(0xFFE3DAC7);
    final roof = Paint()..color = const Color(0xFF41484E);
    final glass = Paint()..color = const Color(0xFF8BB1C5);
    final wood = Paint()..color = const Color(0xFF8A5A36);

    canvas
      ..drawOval(
        box(-66, -5, 132, 11),
        Paint()..color = const Color(0x33203A18),
      )
      ..drawRect(box(-56, -36, 112, 36), wall)
      ..drawRect(box(20, -36, 36, 36), shade)
      ..drawRect(box(-42, -66, 66, 30), wall)
      ..drawPath(
        Path()
          ..moveTo(at(-50, -66).dx, at(-50, -66).dy)
          ..lineTo(at(-9, -86).dx, at(-9, -86).dy)
          ..lineTo(at(32, -66).dx, at(32, -66).dy)
          ..close(),
        roof,
      )
      ..drawRect(box(-62, -39, 124, 4), roof)
      ..drawRect(box(28, -27, 18, 27), wood);
    for (final x in [-49.0, -31.0, -13.0]) {
      canvas.drawRect(box(x, -28, 12, 15), glass);
    }
    for (final x in [-33.0, -15.0, 3.0]) {
      canvas.drawRect(box(x, -59, 11, 14), glass);
    }
  }

  @override
  bool shouldRepaint(LandscapePainter oldDelegate) => false;
}

/// Soft hill silhouettes and contour lines for the foot of the dark sidebar.
class HillsPainter extends CustomPainter {
  const HillsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const layers = [Color(0x14FFFFFF), Color(0x1AFFFFFF), Color(0x26021C14)];
    for (var i = 0; i < layers.length; i++) {
      final base = h * (0.35 + i * 0.2);
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 6; x += 6) {
        final y =
            base -
            h * 0.12 * (0.5 + 0.5 * math.sin(x / w * math.pi * 1.6 + i * 1.9));
        path.lineTo(x, y);
      }
      path
        ..lineTo(w + 6, h)
        ..close();
      canvas.drawPath(path, Paint()..color = layers[i]);
    }
    final contour = Paint()
      ..color = const Color(0x12FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final path = Path();
      for (var x = 0.0; x <= w + 6; x += 6) {
        final y =
            h * (0.2 + i * 0.08) -
            h * 0.06 * math.sin(x / w * math.pi * 1.3 + i * 0.6);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, contour);
    }
  }

  @override
  bool shouldRepaint(HillsPainter oldDelegate) => false;
}
