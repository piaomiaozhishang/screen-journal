import 'package:flutter/material.dart';
import '../../../core/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../services/stats.dart';
import '../../state/app_state.dart';
import '../apps/app_detail.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  TimeRange _range = TimeRange.day;
  int? _donutSel;
  DateTime? _cs; // 自定义区间起
  DateTime? _ce; // 自定义区间止

  bool get _custom => _cs != null && _ce != null;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, now.month, now.day),
      lastDate: now,
      initialDateRange:
          _custom ? DateTimeRange(start: _cs!, end: _ce!) : null,
    );
    if (picked != null && mounted) {
      setState(() {
        _cs = picked.start;
        _ce = picked.end;
        _donutSel = null;
      });
    }
  }

  void _clearCustom() => setState(() {
        _cs = null;
        _ce = null;
        _donutSel = null;
      });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final ranking = s.stats.ranking(_range, now,
        limit: 300, customStart: _cs, customEnd: _ce);
    final slices = s.stats.categorySlices(_range, now,
        customStart: _cs, customEnd: _ce);
    final total = ranking.fold<int>(0, (a, b) => a + b.timeMs);
    final bars = _buildBars(s, now);
    final uncategorized = s.appsOfCategory(null).length;

    // 环形图点击态：中心显示所选分类
    final sel = _donutSel != null && _donutSel! < slices.length ? _donutSel! : null;
    final selSlice = sel == null ? null : slices[sel];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => s.collectNow(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 52, 16, 32),
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.t('屏记'),
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(Fmt.dateCn(now) + _weekday(now.weekday),
                        style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => s.collectNow(),
                  icon: Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            RangeSelector(
                value: _range,
                onChanged: (r) => setState(() {
                      _range = r;
                      _donutSel = null;
                    })),
            SizedBox(height: 10),
            Row(
              children: [
                ActionChip(
                  avatar: Icon(Icons.date_range, size: 16),
                  label: Text(
                    _custom ? '${Fmt.date(_cs!)} ~ ${Fmt.date(_ce!)}' : AppStrings.t('自定义区间'),
                    style: TextStyle(fontSize: 12.5),
                  ),
                  onPressed: _pickCustomRange,
                  visualDensity: VisualDensity.compact,
                ),
                if (_custom) ...[
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearCustom,
                    icon: Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: AppStrings.t('清除自定义区间'),
                  ),
                ],
                const Spacer(),
                if (_custom)
                  Text(
                    '${DayX.diffInDays(_ce!, _cs!) + 1} 天',
                    style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
                  ),
              ],
            ),
            SizedBox(height: 14),
            SectionCard(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_custom ? AppStrings.t('所选区间使用总时长') : '${_range.label}使用总时长',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                  const SizedBox(height: 6),
                  Text(Fmt.duration(Duration(milliseconds: total)),
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
                  const SizedBox(height: 4),
                  Text(AppStrings.nApps(ranking.length),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
            SizedBox(height: 14),
            if (slices.isNotEmpty) ...[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.t('分类占比'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    CategoryDonut(
                      centerTitle: selSlice == null ? AppStrings.t('总计') : selSlice.name,
                      centerLabel: selSlice == null
                          ? Fmt.compact(Duration(milliseconds: total))
                          : Fmt.compact(Duration(milliseconds: selSlice.timeMs)),
                      selectedIndex: sel,
                      onSliceTap: (i) => setState(() => _donutSel = _donutSel == i ? null : i),
                      slices: [
                        for (final sl in slices)
                          DonutSlice(sl.name, sl.timeMs, _sliceColor(sl)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < slices.length && i < 8; i++)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: sel == i
                                  ? _sliceColor(slices[i]).withValues(alpha: 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              CategoryDot(colorValue: _sliceColor(slices[i]).toARGB32()),
                              const SizedBox(width: 5),
                              Text(slices[i].name,
                                  style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                total == 0
                                    ? '0%'
                                    : '${(slices[i].timeMs * 100 / total).round()}%',
                                style: TextStyle(
                                    fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_chartTitle(),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  UsageBarChart(points: bars),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (uncategorized > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(Icons.label_off_outlined, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(AppStrings.uncategorizedHint(uncategorized),
                        style: TextStyle(fontSize: 12.5)),
                  ),
                ]),
              ),
            SectionCard(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
                    child: Text(AppStrings.t('应用排行'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  if (ranking.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(AppStrings.t('暂无使用记录，下拉可立即刷新'),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45), fontSize: 13)),
                    ),
                  for (final r in ranking.take(50))
                    _RankingTile(r: r, total: total, onTap: () => _openApp(r.appId)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _sliceColor(CategorySlice sl) =>
      sl.category == null ? Colors.blueGrey : Color(sl.colorValue);

  String _chartTitle() {
    if (_custom) return AppStrings.t('所选区间每日时长');
    return switch (_range) {
      TimeRange.day => AppStrings.t('今天 24 小时分布'),
      TimeRange.week => AppStrings.t('本周每日时长'),
      TimeRange.month => AppStrings.t('本月每日时长'),
      TimeRange.year => AppStrings.t('今年每月时长'),
      TimeRange.forever => AppStrings.t('每月时长（永久）'),
    };
  }

  List<BarPoint> _buildBars(AppState s, DateTime now) {
    if (_custom) {
      final series = s.stats.dailySeries(null, _cs!, _ce!);
      return [
        for (final e in series)
          BarPoint('${DayX.parseKey(e.key).month}/${DayX.parseKey(e.key).day}', e.value),
      ];
    }
    switch (_range) {
      case TimeRange.day:
        // 按小时（sessions）：只保留有使用的小时，避免 24 根空柱显得杂乱
        final dayStart = DayX.dateOnly(now).millisecondsSinceEpoch;
        final dayEnd = dayStart + 86400000;
        final rows = s.db.db.select(
          'SELECT start_ms st,end_ms en FROM sessions WHERE start_ms>=? AND start_ms<?',
          [dayStart, dayEnd],
        );
        final buckets = List<int>.filled(24, 0);
        for (final r in rows) {
          var st = r['st'] as int;
          var en = r['en'] as int;
          if (st < dayStart) st = dayStart;
          if (en > dayEnd) en = dayEnd;
          var h = DateTime.fromMillisecondsSinceEpoch(st).hour;
          final endH = DateTime.fromMillisecondsSinceEpoch(en).hour;
          while (h <= endH) {
            final hStart = dayStart + h * 3600000;
            final hEnd = hStart + 3600000;
            final ov = (en < hEnd ? en : hEnd) - (st > hStart ? st : hStart);
            if (ov > 0) buckets[h] += ov;
            h++;
          }
        }
        return [
          for (var h = 0; h < 24; h++)
            if (buckets[h] > 0) BarPoint(AppStrings.hour(h), buckets[h]),
        ];
      case TimeRange.week:
        final start = DayX.startOfWeek(now);
        final series = s.stats.dailySeries(null, start, now);
        return [
          for (final e in series)
            BarPoint(AppStrings.weekdayIdx(DayX.parseKey(e.key).weekday), e.value)
        ];
      case TimeRange.month:
        final start = DayX.startOfMonth(now);
        final series = s.stats.dailySeries(null, start, now);
        return [for (final e in series) BarPoint('${DayX.parseKey(e.key).day}', e.value)];
      case TimeRange.year:
        final start = DayX.startOfYear(now);
        final series = s.stats.dailySeries(null, start, now);
        final m = List<int>.filled(12, 0);
        for (final e in series) {
          m[DayX.parseKey(e.key).month - 1] += e.value;
        }
        return [for (var i = 0; i < 12; i++) BarPoint(AppStrings.month(i + 1), m[i])];
      case TimeRange.forever:
        final series = s.stats.dailySeries(
            null, now.subtract(const Duration(days: 1825)), now);
        final months = <String, int>{};
        for (final e in series) {
          final mk = e.key.substring(0, 7);
          months[mk] = (months[mk] ?? 0) + e.value;
        }
        final keys = months.keys.toList()..sort();
        return [
          for (final k in keys)
            BarPoint(AppStrings.month(int.parse(k.substring(5))), months[k]!)
        ];
    }
  }

  String _weekday(int w) => ' ${AppStrings.weekdayIdx(w)}';

  void _openApp(int appId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AppDetailPage(appId: appId)),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final AppTotal r;
  final int total;
  final VoidCallback onTap;
  const _RankingTile({required this.r, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : r.timeMs / total;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            AppIcon(iconPath: r.iconPath, name: r.name, size: 38, uninstalled: r.uninstalled),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    if (r.uninstalled == 1)
                      Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(AppStrings.t('已卸载'),
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
                      ),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.01, 1),
                      minHeight: 4,
                      backgroundColor: Colors.black.withValues(alpha: 0.07),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(Fmt.compact(Duration(milliseconds: r.timeMs)),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
