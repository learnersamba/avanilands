import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/theme.dart';

/// A ring split into coloured parts, drawn clockwise from the top.
class DonutPainter extends CustomPainter {
  const DonutPainter(this.parts);

  final List<(int, Color)> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = parts.fold<int>(0, (sum, part) => sum + part.$1);
    if (total == 0) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint..color = BrandColors.line,
      );
      return;
    }
    final shown = parts.where((part) => part.$1 > 0).toList();
    final gap = shown.length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    for (final (value, color) in shown) {
      final sweep = value / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        paint..color = color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) =>
      oldDelegate.parts.toString() != parts.toString();
}

/// Visitors per day as a line with a soft fill, light grid and axis labels.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.days,
    required this.values,
    required this.labelStyle,
  });

  final List<DateTime> days;
  final List<int> values;
  final TextStyle labelStyle;

  static final _dayLabel = DateFormat('d MMM');

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0, right = 14.0, top = 10.0, bottom = 26.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final highest = values.fold<int>(0, math.max);
    final step = _niceStep(highest / 5);
    final ceiling = step * 5;

    final grid = Paint()
      ..color = BrandColors.line.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = chart.bottom - chart.height * i / 5;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _text(
        canvas,
        _number(step * i),
        Offset(chart.left - 8, y),
        alignRight: true,
      );
    }
    if (values.isEmpty) return;

    double xAt(int i) => values.length == 1
        ? chart.center.dx
        : chart.left + chart.width * i / (values.length - 1);
    double yAt(int value) => chart.bottom - chart.height * value / ceiling;

    final every = (values.length / 7).ceil();
    for (var i = 0; i < values.length; i++) {
      if (i % every != 0 && i != values.length - 1) continue;
      if (i != values.length - 1 && values.length - 1 - i < every) continue;
      _text(
        canvas,
        _dayLabel.format(days[i]),
        Offset(xAt(i), chart.bottom + 16),
        centre: true,
      );
    }

    final line = Path()..moveTo(xAt(0), yAt(values[0]));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(xAt(i), yAt(values[i]));
    }
    final area = Path.from(line)
      ..lineTo(xAt(values.length - 1), chart.bottom)
      ..lineTo(xAt(0), chart.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            BrandColors.available.withValues(alpha: 0.22),
            BrandColors.available.withValues(alpha: 0.02),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = BrandColors.available
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (values.length <= 14) {
      for (var i = 0; i < values.length; i++) {
        final point = Offset(xAt(i), yAt(values[i]));
        canvas
          ..drawCircle(point, 4.5, Paint()..color = Colors.white)
          ..drawCircle(
            point,
            4.5,
            Paint()
              ..color = BrandColors.available
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool alignRight = false,
    bool centre = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? at.dx - painter.width
        : (centre ? at.dx - painter.width / 2 : at.dx);
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  static String _number(int value) =>
      value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '$value';

  /// 1, 2, 2.5, 5 or 10 times a power of ten, at least [raw].
  static int _niceStep(double raw) {
    if (raw <= 1) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * magnitude >= raw) return (m * magnitude).ceil();
    }
    return (10 * magnitude).ceil();
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString();
}

/// Tiny bar chart for a stat card; the last bar (today) is full colour.
class MiniBarsPainter extends CustomPainter {
  const MiniBarsPainter(this.values, this.color);

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final highest = math.max(1, values.fold<int>(0, math.max));
    final slot = size.width / values.length;
    final width = slot * 0.62;
    for (var i = 0; i < values.length; i++) {
      final height = math.max(3.0, size.height * values[i] / highest);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * slot + (slot - width) / 2,
          size.height - height,
          width,
          height,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = i == values.length - 1
              ? color
              : color.withValues(alpha: 0.35 + 0.35 * i / values.length),
      );
    }
  }

  @override
  bool shouldRepaint(MiniBarsPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString();
}
