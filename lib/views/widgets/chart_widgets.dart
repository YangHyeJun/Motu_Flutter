import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = List.generate(8, (index) => 12.0 + index * 3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Icon(Icons.trending_up, color: Color(0xFF18AD5A), size: 18),
        const SizedBox(width: 8),
        ...bars.map(
          (height) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 6,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF15B24E),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StockLineChart extends StatelessWidget {
  const StockLineChart({super.key, required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter(this.points);

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final borderRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(borderRect, borderPaint);

    if (points.isEmpty) {
      return;
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final dx = i / (points.length - 1) * (size.width - 32) + 16;
      final dy = (1 - points[i]) * (size.height - 40) + 20;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFF5263)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
