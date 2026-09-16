import 'package:fl_chart/fl_chart.dart';
import '../../../core/l10n.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';

class ChartPoint {
  final String label;
  final int ms;
  final Color? color;
  const ChartPoint(this.label, this.ms, {this.color});
}

/// 通用趋势波形图（平滑曲线 + 渐变面积，日/周/月/年/永久序列通用）
class UsageWaveChart extends StatelessWidget {
  final List<ChartPoint> points;
  final double height;
  const UsageWaveChart({super.key, required this.points, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(AppStrings.t('暂无数据'),
              style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.38))),
        ),
      );
    }
    final maxMs = points.map((p) => p.ms).fold<int>(0, (a, b) => a > b ? a : b);
    final base = scheme.primary;
    final grid = scheme.onSurface.withValues(alpha: 0.06);
    final mins = points.map((p) => p.ms / 60000).toList();

    final labelStep = (points.length / 6).ceil().clamp(1, 100);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxMs / 60000) * 1.25 + 0.5,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), mins[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.32,
              preventCurveOverShooting: true,
              color: base,
              barWidth: 2.6,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: points.length <= 31,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(radius: 2.6, color: base, strokeWidth: 0),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    base.withValues(alpha: 0.30),
                    base.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, meta) {
                  if (v == meta.max || v == meta.min) return const SizedBox.shrink();
                  return Text('${v.round()}',
                      style: TextStyle(fontSize: 9, color: scheme.onSurface.withValues(alpha: 0.38)));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= points.length || i % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[i].label,
                        style: TextStyle(fontSize: 9, color: scheme.onSurface.withValues(alpha: 0.45))),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final sp in spots)
                  LineTooltipItem(
                    '${points[sp.spotIndex].label}\n${Fmt.duration(Duration(milliseconds: points[sp.spotIndex].ms))}',
                    TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DonutSlice {
  final String name;
  final int ms;
  final Color color;
  const DonutSlice(this.name, this.ms, this.color);
}

class CategoryDonut extends StatelessWidget {
  final List<DonutSlice> slices;
  final String centerTitle;
  final String centerLabel;
  final int? selectedIndex;
  final ValueChanged<int?>? onSliceTap;
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerTitle,
    required this.centerLabel,
    this.selectedIndex,
    this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 56,
            sections: [
              for (var i = 0; i < slices.length; i++)
                PieChartSectionData(
                  value: slices[i].ms.toDouble(),
                  color: slices[i].color,
                  showTitle: false,
                  radius: selectedIndex == i ? 31 : 26,
                  borderSide: selectedIndex == i
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.surface, width: 3)
                      : BorderSide.none,
                ),
            ],
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                if (event is! FlTapUpEvent) return;
                final idx = response?.touchedSection?.touchedSectionIndex;
                onSliceTap?.call(idx);
              },
            ),
          )),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
              const SizedBox(height: 2),
              Text(centerLabel,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单应用某天 24 小时使用片段时间轴
class DayTimeline extends StatelessWidget {
  final List<(int startMs, int endMs)> segments; // 当天片段
  final DateTime day;
  final Color color;
  const DayTimeline(
      {super.key, required this.segments, required this.day, this.color = const Color(0xFF1F9E89)});

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TimelinePainter(
              segments: segments.map((s) {
                final from = ((s.$1 - dayStart) / 86400000).clamp(0.0, 1.0);
                final to = ((s.$2 - dayStart) / 86400000).clamp(0.0, 1.0);
                return (from, to);
              }).toList(),
              color: Theme.of(context).colorScheme.primary,
              track: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.t('0时'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
            Text(AppStrings.t('6时'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
            Text(AppStrings.t('12时'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
            Text(AppStrings.t('18时'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
            Text(AppStrings.t('24时'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
          ],
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final List<(double, double)> segments;
  final Color color;
  final Color track;
  _TimelinePainter({required this.segments, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = track;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(rrect, trackPaint);
    final paint = Paint()..color = color;
    for (final s in segments) {
      final l = s.$1 * size.width;
      final r = s.$2 * size.width;
      if (r - l < 0.5) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(l, 0, r, size.height), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => old.segments != segments;
}
