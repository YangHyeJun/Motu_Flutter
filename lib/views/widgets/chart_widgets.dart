import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/stock_detail.dart';

class StockLineChart extends StatefulWidget {
  const StockLineChart({
    super.key,
    required this.entries,
    this.valueSuffix = '원',
    this.valueFormatter,
  });

  final List<StockChartEntry> entries;
  final String valueSuffix;
  final String Function(int value)? valueFormatter;

  @override
  State<StockLineChart> createState() => _StockLineChartState();
}

class _StockLineChartState extends State<StockLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.entries.isEmpty) {
          return const SizedBox.expand();
        }

        final width = constraints.maxWidth;
        final chartWidth = math.max(width - 48, 1);
        final selectedIndex = _selectedIndex ?? (widget.entries.length - 1);
        final selectedEntry = widget.entries[selectedIndex];
        final selectedDx = widget.entries.length == 1
            ? width / 2
            : 24 + (selectedIndex / (widget.entries.length - 1)) * chartWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) => _updateSelection(details.localPosition.dx, width),
          onLongPressMoveUpdate: (details) => _updateSelection(details.localPosition.dx, width),
          onPanStart: (details) => _updateSelection(details.localPosition.dx, width),
          onPanUpdate: (details) => _updateSelection(details.localPosition.dx, width),
          onPanEnd: (_) => setState(() => _selectedIndex = null),
          onTapDown: (details) => _updateSelection(details.localPosition.dx, width),
          onTapUp: (_) => setState(() => _selectedIndex = null),
          onTapCancel: () => setState(() => _selectedIndex = null),
          onLongPressEnd: (_) => setState(() => _selectedIndex = null),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _LineChartPainter(
                    entries: widget.entries,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
              if (_selectedIndex != null)
                Positioned(
                  left: math.max(8, math.min(selectedDx - 40, width - 88)),
                  top: 8,
                  child: _Tooltip(
                    price: widget.valueFormatter != null
                        ? widget.valueFormatter!(selectedEntry.closePrice)
                        : '${_formatNumber(selectedEntry.closePrice)}${widget.valueSuffix}',
                    label: selectedEntry.timeLabel,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _AxisLabels(entries: widget.entries),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateSelection(double dx, double width) {
    if (widget.entries.isEmpty) {
      return;
    }

    final clamped = dx.clamp(24.0, math.max(width - 24, 24));
    final ratio = widget.entries.length == 1
        ? 0.0
        : (clamped - 24) / math.max(width - 48, 1);
    final index = (ratio * (widget.entries.length - 1))
        .round()
        .clamp(0, widget.entries.length - 1);
    setState(() => _selectedIndex = index);
  }
}

class VolumeBarChart extends StatefulWidget {
  const VolumeBarChart({super.key, required this.entries});

  final List<StockChartEntry> entries;

  @override
  State<VolumeBarChart> createState() => _VolumeBarChartState();
}

class _VolumeBarChartState extends State<VolumeBarChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.entries.isEmpty) {
          return const SizedBox.expand();
        }

        final width = constraints.maxWidth;
        final chartWidth = math.max(width - 48, 1);
        final selectedIndex = _selectedIndex ?? (widget.entries.length - 1);
        final selectedEntry = widget.entries[selectedIndex];
        final selectedDx = widget.entries.length == 1
            ? width / 2
            : 24 + (selectedIndex / (widget.entries.length - 1)) * chartWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) => _updateSelection(details.localPosition.dx, width),
          onLongPressMoveUpdate: (details) => _updateSelection(details.localPosition.dx, width),
          onPanStart: (details) => _updateSelection(details.localPosition.dx, width),
          onPanUpdate: (details) => _updateSelection(details.localPosition.dx, width),
          onPanEnd: (_) => setState(() => _selectedIndex = null),
          onTapDown: (details) => _updateSelection(details.localPosition.dx, width),
          onTapUp: (_) => setState(() => _selectedIndex = null),
          onTapCancel: () => setState(() => _selectedIndex = null),
          onLongPressEnd: (_) => setState(() => _selectedIndex = null),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _VolumeBarChartPainter(
                    widget.entries,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
              if (_selectedIndex != null)
                Positioned(
                  left: math.max(8, math.min(selectedDx - 40, width - 88)),
                  top: 8,
                  child: _Tooltip(
                    price: '${_formatNumber(selectedEntry.volume)}주',
                    label: selectedEntry.timeLabel,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _updateSelection(double dx, double width) {
    if (widget.entries.isEmpty) {
      return;
    }

    final clamped = dx.clamp(24.0, math.max(width - 24, 24));
    final ratio = widget.entries.length == 1
        ? 0.0
        : (clamped - 24) / math.max(width - 48, 1);
    final index = (ratio * (widget.entries.length - 1))
        .round()
        .clamp(0, widget.entries.length - 1);
    setState(() => _selectedIndex = index);
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.entries,
    required this.selectedIndex,
  });

  final List<StockChartEntry> entries;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 8.0;
    const topPadding = 18.0;
    const bottomPadding = 12.0;

    if (entries.isEmpty) {
      return;
    }

    final prices = entries.map((entry) => entry.closePrice.toDouble()).toList();
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final gap = (maxPrice - minPrice) == 0 ? 1.0 : (maxPrice - minPrice);

    final points = <Offset>[];
    for (var i = 0; i < prices.length; i++) {
      final dx = entries.length == 1
          ? size.width / 2
          : i / (entries.length - 1) * (size.width - (horizontalPadding * 2)) + horizontalPadding;
      final normalized = (prices[i] - minPrice) / gap;
      final dy = (1 - normalized) * (size.height - topPadding - bottomPadding) + topPadding;
      points.add(Offset(dx, dy));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height - bottomPadding);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, size.height - bottomPadding);
    fillPath.close();

    final areaPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x33FF5263),
          Color(0x05FF5263),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, areaPaint);

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFFF5263)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < points.length) {
      final selectedPoint = points[selected];
      final guidePaint = Paint()
        ..color = const Color(0xFF9FA5B2)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(selectedPoint.dx, topPadding - 6),
        Offset(selectedPoint.dx, size.height - bottomPadding),
        guidePaint,
      );

      final dotPaint = Paint()..color = const Color(0xFFFF5263);
      canvas.drawCircle(selectedPoint, 5, dotPaint);
      canvas.drawCircle(selectedPoint, 10, dotPaint..color = const Color(0x22FF5263));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.selectedIndex != selectedIndex;
  }
}

class _VolumeBarChartPainter extends CustomPainter {
  _VolumeBarChartPainter(this.entries, {required this.selectedIndex});

  final List<StockChartEntry> entries;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 8.0;
    const topPadding = 18.0;
    const bottomPadding = 12.0;

    if (entries.isEmpty) {
      return;
    }

    final maxVolume = entries
        .map((entry) => entry.volume.toDouble())
        .reduce((left, right) => left > right ? left : right);
    if (maxVolume <= 0) {
      return;
    }

    final count = entries.length;
    final availableWidth = size.width - (horizontalPadding * 2);
    final barWidth = math.max(availableWidth / (count * 1.4), 2).toDouble();
    final gap = barWidth * 0.4;

    for (var i = 0; i < count; i++) {
      final ratio = entries[i].volume / maxVolume;
      final barHeight = (size.height - topPadding - bottomPadding) * ratio;
      final left = horizontalPadding + (barWidth + gap) * i;
      final paint = Paint()
        ..color = i == selectedIndex ? const Color(0xFF4B84FF) : const Color(0xFFBFD8FF)
        ..style = PaintingStyle.fill;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          size.height - bottomPadding - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumeBarChartPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.selectedIndex != selectedIndex;
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.price,
    required this.label,
  });

  final String price;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              price,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.entries});

  final List<StockChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final middleIndex = entries.length ~/ 2;
    final labels = [
      entries.first.timeLabel,
      entries[middleIndex].timeLabel,
      entries.last.timeLabel,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: labels.map((label) {
          return Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: label == labels.first
                  ? TextAlign.left
                  : label == labels.last
                      ? TextAlign.right
                      : TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8B93A1),
                fontSize: 11,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final fromEnd = digits.length - i - 1;
    if (fromEnd > 0 && fromEnd % 3 == 0) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}
