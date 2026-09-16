import 'package:fl_chart/fl_chart.dart';
import '../../../core/l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../apps/app_detail.dart';
import '../widgets/common.dart';

class CompareTab extends StatefulWidget {
  const CompareTab({super.key});

  @override
  State<CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends State<CompareTab> {
  TimeRange _range = TimeRange.week;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final result = s.stats.compare(_range, now);
    final pairs = _pairs(s, now);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('对比'), style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          RangeSelector(
            value: _range,
            allowForever: false,
            onChanged: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TotalCard(
                  label: _currentLabel(now),
                  ms: result.currentTotal,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TotalCard(
                  label: _previousLabel(now),
                  ms: result.previousTotal,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SectionCard(
            color: _deltaColor(result.ratio).withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(_deltaIcon(result.ratio), color: _deltaColor(result.ratio)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.ratio == null
                        ? AppStrings.t('上一周期无记录')
                        : '${AppStrings.t('相比上')}${_range.label} ${AppStrings.t(result.ratio! >= 0 ? '增加' : '减少')} '
                            '${(result.ratio!.abs() * 100).toStringAsFixed(1)}%'
                            '（${Fmt.duration(Duration(milliseconds: result.deltaMs.abs()))}）',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _deltaColor(result.ratio)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_chartName(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _legend(Theme.of(context).colorScheme.primary, _currentLabel(now)),
                  const SizedBox(width: 12),
                  _legend(Colors.blueGrey, _previousLabel(now)),
                ]),
                const SizedBox(height: 6),
                SizedBox(height: 200, child: _pairChart(pairs)),
              ],
            ),
          ),
          SizedBox(height: 14),
          SectionCard(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Text(AppStrings.t('应用对比'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (result.items.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(AppStrings.t('暂无数据'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                  ),
                for (final it in result.items.where((i) => i.currentMs + i.previousMs > 0).take(50))
                  _CompareTile(item: it),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _currentLabel(DateTime now) => switch (_range) {
        TimeRange.day => AppStrings.t('今天'),
        TimeRange.week => AppStrings.t('本周'),
        TimeRange.month => AppStrings.t('本月'),
        TimeRange.year => AppStrings.t('今年'),
        TimeRange.forever => '',
      };

  String _previousLabel(DateTime now) => switch (_range) {
        TimeRange.day => AppStrings.t('昨天'),
        TimeRange.week => AppStrings.t('上周'),
        TimeRange.month => AppStrings.t('上月'),
        TimeRange.year => AppStrings.t('去年'),
        TimeRange.forever => '',
      };

  String _chartName() => switch (_range) {
        TimeRange.day => AppStrings.t('24 小时对比'),
        TimeRange.week => AppStrings.t('周一 ~ 周日对比'),
        TimeRange.month => AppStrings.t('按日对比'),
        TimeRange.year => AppStrings.t('按月对比'),
        TimeRange.forever => '',
      };

  IconData _deltaIcon(double? r) {
    if (r == null) return Icons.remove;
    if (r > 0.005) return Icons.arrow_upward;
    if (r < -0.005) return Icons.arrow_downward;
    return Icons.drag_handle;
  }

  Color _deltaColor(double? r) {
    if (r == null) return Colors.blueGrey;
    if (r > 0.005) return const Color(0xFFE53935); // 用时增加=红
    if (r < -0.005) return const Color(0xFF43A047); // 减少=绿
    return Colors.blueGrey;
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(t, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
      ]);

  // 返回 (label, currentMs, previousMs) 序列
  List<_Pair> _pairs(AppState s, DateTime now) {
    List<int> hourBuckets(DateTime day) {
      final ds = DayX.dateOnly(day).millisecondsSinceEpoch;
      final rows = s.db.db.select(
        'SELECT start_ms st,end_ms en FROM sessions WHERE start_ms>=? AND start_ms<?',
        [ds, ds + 86400000],
      );
      final b = List<int>.filled(24, 0);
      for (final r in rows) {
        var st = r['st'] as int;
        var en = r['en'] as int;
        if (st < ds) st = ds;
        if (en > ds + 86400000) en = ds + 86400000;
        var h = DateTime.fromMillisecondsSinceEpoch(st).hour;
        final endH = DateTime.fromMillisecondsSinceEpoch(en).hour;
        while (h <= endH) {
          final hs = ds + h * 3600000;
          final he = hs + 3600000;
          final ov = (en < he ? en : he) - (st > hs ? st : hs);
          if (ov > 0) b[h] += ov;
          h++;
        }
      }
      return b;
    }

    Map<String, int> globalDaily(String a, String b) {
      final rows = s.db.db.select(
        'SELECT day d, SUM(time_ms) t FROM daily_usage WHERE day>=? AND day<=? GROUP BY day',
        [a, b],
      );
      return {for (final r in rows) r['d'] as String: r['t'] as int};
    }

    switch (_range) {
      case TimeRange.day:
        final y = DayX.dateOnly(now).subtract(const Duration(days: 1));
        final c = hourBuckets(now);
        final p = hourBuckets(y);
        return [for (var h = 0; h < 24; h++) _Pair('$h', c[h], p[h])];
      case TimeRange.week:
        final ws = DayX.startOfWeek(now);
        final ps = ws.subtract(const Duration(days: 7));
        final cd = globalDaily(DayX.keyOf(ws), DayX.keyOf(now));
        final pd = globalDaily(DayX.keyOf(ps), DayX.keyOf(ps.add(const Duration(days: 6))));
        return List.generate(7, (i) {
          return _Pair(
            AppStrings.weekdayIdx(i + 1),
            cd[DayX.keyOf(ws.add(Duration(days: i)))] ?? 0,
            pd[DayX.keyOf(ps.add(Duration(days: i)))] ?? 0,
          );
        });
      case TimeRange.month:
        final n = now.day;
        final pm = DateTime(now.year, now.month - 1, 1);
        final cm = DateTime(now.year, now.month, 1);
        final cd = globalDaily(DayX.keyOf(cm), DayX.keyOf(now));
        final pd = globalDaily(
            DayX.keyOf(pm), DayX.keyOf(pm.add(Duration(days: n - 1))));
        return List.generate(n, (i) {
          return _Pair(
            '${i + 1}',
            cd[DayX.keyOf(cm.add(Duration(days: i)))] ?? 0,
            pd[DayX.keyOf(pm.add(Duration(days: i)))] ?? 0,
          );
        });
      case TimeRange.year:
        final cy = DayX.startOfYear(now);
        final py = DateTime(now.year - 1, 1, 1);
        final cd = globalDaily(DayX.keyOf(cy), DayX.keyOf(now));
        final pd = globalDaily(DayX.keyOf(py), DayX.keyOf(DateTime(now.year - 1, 12, 31)));
        List<int> sumByMonth(Map<String, int> d) {
          final m = List<int>.filled(12, 0);
          d.forEach((k, v) => m[int.parse(k.substring(5, 7)) - 1] += v);
          return m;
        }
        final c = sumByMonth(cd), p = sumByMonth(pd);
        return [for (var i = 0; i < 12; i++) _Pair(AppStrings.month(i + 1), c[i], p[i])];
      case TimeRange.forever:
        return const [];
    }
  }

  Widget _pairChart(List<_Pair> pairs) {
    final maxV = pairs
        .map((p) => p.$2 > p.$3 ? p.$2 : p.$3)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final cs = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxV / 60000) * 1.25 + 1,
        barGroups: [
          for (var i = 0; i < pairs.length; i++)
            BarChartGroupData(x: i, barsSpace: 2, barRods: [
              BarChartRodData(
                  toY: pairs[i].$2 / 60000,
                  color: cs.primary,
                  width: pairs.length > 12 ? 4 : 7,
                  borderRadius: BorderRadius.zero),
              BarChartRodData(
                  toY: pairs[i].$3 / 60000,
                  color: cs.onSurfaceVariant,
                  width: pairs.length > 12 ? 4 : 7,
                  borderRadius: BorderRadius.zero),
            ]),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.onSurface.withValues(alpha: 0.06), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, meta) {
                if (v == meta.max) return const SizedBox.shrink();
                return Text('${v.round()}',
                    style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (pairs.length / 6).ceilToDouble(),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= pairs.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(pairs[i].$1,
                      style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ($1 label,$2 current,$3 previous)
class _Pair {
  final String $1;
  final int $2;
  final int $3;
  _Pair(this.$1, this.$2, this.$3);
}

class _TotalCard extends StatelessWidget {
  final String label;
  final int ms;
  final Color color;
  const _TotalCard({required this.label, required this.ms, required this.color});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: color.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
          const SizedBox(height: 6),
          Text(Fmt.duration(Duration(milliseconds: ms)),
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _CompareTile extends StatelessWidget {
  final CompareItem item;
  const _CompareTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final up = item.deltaMs > 0;
    final flat = item.deltaMs == 0;
    final color = flat
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)
        : up
            ? const Color(0xFFE53935)
            : const Color(0xFF43A047);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AppDetailPage(appId: item.appId)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            AppIcon(iconPath: item.iconPath, name: item.name, size: 36,
                uninstalled: item.uninstalled),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              width: 64,
              child: Text(Fmt.compact(Duration(milliseconds: item.currentMs)),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 58,
              child: Text(Fmt.compact(Duration(milliseconds: item.previousMs)),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
            ),
            SizedBox(
              width: 62,
              child: Text(
                flat
                    ? '—'
                    : '${up ? '+' : '-'}${Fmt.compact(Duration(milliseconds: item.deltaMs.abs()))}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
