import 'package:flutter/material.dart';
import '../../../core/l10n.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class AppDetailPage extends StatefulWidget {
  final int appId;
  const AppDetailPage({super.key, required this.appId});

  @override
  State<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  TimeRange _range = TimeRange.day;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final AppEntry app;
    try {
      app = s.appById(widget.appId);
    } catch (_) {
      return Scaffold(body: Center(child: Text(AppStrings.t('应用记录不存在'))));
    }
    final stats = s.stats.appStats(app.id);
    final now = DateTime.now();
    final rangeMs = s.stats.rangeTotal(app.id, _range, now);
    final cats = s.categories;
    final myCatIds = s.categoryIdsOfApp(app.id);
    final todayMs = s.stats.totalOnDay(app.id, now);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('应用详情')),
        actions: [
          IconButton(onPressed: () => s.collectNow(), icon: Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SectionCard(
            child: Row(
              children: [
                AppIcon(
                    iconPath: app.iconPath,
                    name: app.name,
                    size: 56,
                    uninstalled: app.uninstalled),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(app.package,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                      SizedBox(height: 4),
                      Row(children: [
                        Text(app.platform == 'android' ? 'Android' : 'Windows',
                            style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                        if (app.uninstalled == 1) ...[
                          SizedBox(width: 8),
                          Text(AppStrings.t('当前未安装 · 数据保留'),
                              style: TextStyle(fontSize: 10.5, color: Colors.orange)),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(AppStrings.t('分类标签'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Spacer(),
                  TextButton.icon(
                    icon: Icon(Icons.edit, size: 17),
                    label: Text(AppStrings.t('编辑')),
                    onPressed: () => _editTags(app, myCatIds.toSet(), cats),
                  ),
                ]),
                SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (myCatIds.isEmpty)
                      Chip(label: Text(AppStrings.t('未分类')), visualDensity: VisualDensity.compact),
                    for (final cid in myCatIds)
                      Builder(builder: (_) {
                        final c = cats.firstWhere((c) => c.id == cid);
                        return Chip(
                          label: Text(c.name),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Color(c.colorValue).withValues(alpha: 0.14),
                          side: BorderSide.none,
                          labelStyle: TextStyle(color: Color(c.colorValue), fontSize: 12),
                        );
                      }),
                  ],
                ),
                const Divider(height: 26),
                _InstallDate(app: app, onChanged: (d) {
                  s.updateApp(app.copyWith(
                    installDateMs: d?.millisecondsSinceEpoch,
                    clearInstallDate: d == null,
                  ));
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RangeSelector(value: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: 12),
          SectionCard(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_range.label}使用时长',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                const SizedBox(height: 4),
                Text(Fmt.duration(Duration(milliseconds: rangeMs)),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (_range == TimeRange.day)
                  DayTimeline(day: DayX.dateOnly(now), segments: _todaySegments(s, app.id, now))
                else
                  UsageBarChart(points: _series(s, app.id, _range, now), height: 180),
              ],
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.32,
            children: [
              StatTile(
                  label: AppStrings.t('平均每日'),
                  value: Fmt.compact(Duration(milliseconds: stats.avgPerDayMs)),
                  icon: Icons.timelapse,
                  hint: stats.firstDay == null
                      ? null
                      : AppStrings.since(stats.firstDay!)),
              StatTile(
                  label: AppStrings.t('当前连续'),
                  value: AppStrings.nDays(stats.currentStreak),
                  icon: Icons.local_fire_department_outlined),
              StatTile(
                  label: AppStrings.t('最长连续'),
                  value: AppStrings.nDays(stats.longestStreak),
                  icon: Icons.military_tech_outlined),
              StatTile(
                  label: AppStrings.t('最高单日'),
                  value: Fmt.compact(Duration(milliseconds: stats.maxDailyMs)),
                  icon: Icons.vertical_align_top,
                  hint: stats.maxDailyDay),
              StatTile(label: AppStrings.t('使用天数'), value: AppStrings.nDays(stats.activeDays), icon: Icons.event_available),
              StatTile(
                  label: AppStrings.t('累计时长'),
                  value: Fmt.compact(Duration(milliseconds: stats.totalMs)),
                  icon: Icons.all_inclusive),
            ],
          ),
          const SizedBox(height: 12),
          _LimitCard(app: app, todayMs: todayMs),
          const SizedBox(height: 12),
          _RatingDescCard(app: app),
          const SizedBox(height: 12),
          _SourcesCard(app: app),
        ],
      ),
    );
  }

  List<(int, int)> _todaySegments(AppState s, int appId, DateTime now) {
    final dayStart = DayX.dateOnly(now).millisecondsSinceEpoch;
    final sessions = s.db.sessionsBetween(appId, dayStart, dayStart + 86400000);
    return sessions.map((e) => (e.startMs, e.endMs)).toList();
  }

  List<BarPoint> _series(AppState s, int appId, TimeRange range, DateTime now) {
    DateTime start;
    switch (range) {
      case TimeRange.week:
        start = DayX.startOfWeek(now);
        final series = s.stats.dailySeries(appId, start, now);
        return [
          for (final e in series)
            BarPoint(AppStrings.weekdayIdx(DayX.parseKey(e.key).weekday), e.value)
        ];
      case TimeRange.month:
        start = DayX.startOfMonth(now);
        final series = s.stats.dailySeries(appId, start, now);
        return [for (final e in series) BarPoint('${DayX.parseKey(e.key).day}', e.value)];
      case TimeRange.year:
        start = DayX.startOfYear(now);
        final series = s.stats.dailySeries(appId, start, now);
        final m = List<int>.filled(12, 0);
        for (final e in series) {
          m[DayX.parseKey(e.key).month - 1] += e.value;
        }
        return [for (var i = 0; i < 12; i++) BarPoint(AppStrings.month(i + 1), m[i])];
      case TimeRange.forever:
        final first = s.db.firstUsageDay(appId);
        start = first == null
            ? now.subtract(const Duration(days: 365))
            : DayX.parseKey(first);
        final series = s.stats.dailySeries(appId, start, now);
        final months = <String, int>{};
        for (final e in series) {
          final mk = e.key.substring(0, 7);
          months[mk] = (months[mk] ?? 0) + e.value;
        }
        final keys = months.keys.toList()..sort();
        return [for (final k in keys) BarPoint(k.substring(2), months[k]!)];
      case TimeRange.day:
        return const [];
    }
  }

  Future<void> _editTags(AppEntry app, Set<int> selected, List<Category> cats) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(AppStrings.t('选择分类（可多选）'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (cats.isEmpty)
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(AppStrings.t('还没有分类，请到“分类”页新建'),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in cats)
                      CheckboxListTile(
                        value: selected.contains(c.id),
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            selected.add(c.id);
                          } else {
                            selected.remove(c.id);
                          }
                        }),
                        secondary: Icon(cpIcon(c.iconCodePoint), color: Color(c.colorValue)),
                        title: Text(c.name),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(14),
                child: FilledButton(
                  child: Text(AppStrings.t('保存')),
                  onPressed: () {
                    context.read<AppState>().setAppCategories(app.id, selected.toList());
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _InstallDate extends StatelessWidget {
  final AppEntry app;
  final ValueChanged<DateTime?> onChanged;
  const _InstallDate({required this.app, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.event, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
        SizedBox(width: 8),
        Text(AppStrings.t('安装日期'), style: TextStyle(fontSize: 13.5)),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final initial = app.installDate ?? DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(Duration(days: 1)),
            );
            if (d != null) onChanged(d);
          },
          child: Text(app.installDate == null ? AppStrings.t('设置日期') : Fmt.date(app.installDate!)),
        ),
        if (app.installDateMs != null)
          IconButton(
            icon: Icon(Icons.close, size: 16),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

class _LimitCard extends StatefulWidget {
  final AppEntry app;
  final int todayMs;
  const _LimitCard({required this.app, required this.todayMs});

  @override
  State<_LimitCard> createState() => _LimitCardState();
}

class _LimitCardState extends State<_LimitCard> {
  late int _minutes = widget.app.dailyLimitMinutes ?? 60;

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final enabled = widget.app.dailyLimitMinutes != null;
    final limitMs = (widget.app.dailyLimitMinutes ?? _minutes) * 60000;
    final pct = limitMs == 0 ? 0.0 : (widget.todayMs / limitMs).clamp(0.0, 1.0);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.timer_off_outlined, size: 19),
            SizedBox(width: 8),
            Text(AppStrings.t('每日使用限额'),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Switch(
              value: enabled,
              onChanged: (v) {
                s.updateApp(widget.app.copyWith(
                  dailyLimitMinutes: v ? _minutes : null,
                  clearLimit: !v,
                ));
                setState(() {});
              },
            ),
          ]),
          if (enabled) ...[
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline),
                  onPressed: () => _set((widget.app.dailyLimitMinutes ?? 60) - 5),
                ),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    key: ValueKey(widget.app.dailyLimitMinutes),
                    initialValue: '${widget.app.dailyLimitMinutes}',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(isDense: true, suffixText: AppStrings.t('分钟')),
                    onFieldSubmitted: (v) => _set(int.tryParse(v) ?? 60),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline),
                  onPressed: () => _set((widget.app.dailyLimitMinutes ?? 60) + 5),
                ),
                Spacer(),
                FilledButton.tonal(
                  onPressed: () => _set(widget.app.dailyLimitMinutes ?? 60),
                  child: Text(AppStrings.t('保存')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.black.withValues(alpha: 0.07),
                color: pct >= 1 ? Colors.red : Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '${AppStrings.t('今日已用')} ${Fmt.duration(Duration(milliseconds: widget.todayMs))} / '
              '${Fmt.duration(Duration(milliseconds: limitMs))}',
              style: TextStyle(
                  fontSize: 12, color: pct >= 1 ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
            ),
            SizedBox(height: 6),
            Text(
              AppStrings.t('达到限额时会全屏提醒并自动回到桌面（需在引导/设置中开启悬浮窗与无障碍权限）。')
              + AppStrings.t('受 Android 限制，普通应用无法直接强制关闭其他应用。'),
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), height: 1.5),
            ),
          ] else
            Text(AppStrings.t('开启后，当日使用达到限额将被强制提醒并回到桌面。'),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
        ],
      ),
    );
  }

  void _set(int v) {
    v = v.clamp(1, 1440);
    setState(() => _minutes = v);
    context.read<AppState>().updateApp(widget.app.copyWith(dailyLimitMinutes: v));
  }
}

class _RatingDescCard extends StatefulWidget {
  final AppEntry app;
  const _RatingDescCard({required this.app});

  @override
  State<_RatingDescCard> createState() => _RatingDescCardState();
}

class _RatingDescCardState extends State<_RatingDescCard> {
  late final TextEditingController _desc =
      TextEditingController(text: widget.app.description ?? '');

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_half_rounded, size: 19),
            SizedBox(width: 8),
            Text(AppStrings.t('评分与描述'), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            Spacer(),
            Text(widget.app.rating == null ? AppStrings.t('未评分') : '${widget.app.rating!.round()} / 10',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
          ]),
          Slider(
            value: widget.app.rating ?? 0,
            min: 0,
            max: 10,
            divisions: 10,
            label: widget.app.rating == null ? AppStrings.t('不评分') : '${widget.app.rating!.round()} 分',
            onChanged: (v) => s.updateApp(widget.app.copyWith(
              rating: v == 0 ? null : v,
              clearRating: v == 0,
            )),
          ),
          SizedBox(height: 4),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: AppStrings.t('记录你对这个应用的评价、用途、注意事项…'),
            ),
            onChanged: (v) {
              s.updateApp(widget.app.copyWith(
                description: v.trim().isEmpty ? null : v,
                clearDescription: v.trim().isEmpty,
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  final AppEntry app;
  const _SourcesCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sources = s.sourcesOf(app.id);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.link, size: 19),
            SizedBox(width: 8),
            Text(AppStrings.t('软件来源'), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            Spacer(),
            TextButton.icon(
              icon: Icon(Icons.add, size: 18),
              label: Text(AppStrings.t('添加')),
              onPressed: () => _addSource(context),
            ),
          ]),
          if (sources.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(AppStrings.t('添加下载页面、GitHub、网盘、Telegram 等链接，点击即可跳转。'),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45), height: 1.5)),
            ),
          for (final src in sources)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                src.url == null ? Icons.notes_outlined : Icons.open_in_new,
                size: 19,
                color: src.url == null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45) : Theme.of(context).colorScheme.primary,
              ),
              title: Text(src.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: src.url == null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87) : Theme.of(context).colorScheme.primary,
                      decoration: src.url == null ? null : TextDecoration.underline)),
              subtitle: src.url == null ? null : Text(src.url!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
              onTap: src.url == null ? null : () => _openLink(context, src.url!),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') s.deleteSource(src.id);
                  if (v == 'edit') _editSource(context, src);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(AppStrings.t('编辑'))),
                  PopupMenuItem(value: 'delete', child: Text(AppStrings.t('删除'))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.contains('://')) url = 'https://$url';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${AppStrings.t('无法打开链接')}：$url（${AppStrings.t('可能未安装对应应用')}）')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${AppStrings.t('打开失败')}：$e')));
      }
    }
  }

  Future<void> _addSource(BuildContext context) => _sourceDialog(context, null);
  Future<void> _editSource(BuildContext context, AppSource src) =>
      _sourceDialog(context, src);

  Future<void> _sourceDialog(BuildContext context, AppSource? existing) async {
    final s = context.read<AppState>();
    final labelCtl = TextEditingController(text: existing?.label ?? '');
    final urlCtl = TextEditingController(text: existing?.url ?? '');
    var isLink = existing?.url != null || true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? AppStrings.t('添加来源') : AppStrings.t('编辑来源')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(AppStrings.t('链接')), icon: Icon(Icons.link, size: 16)),
                  ButtonSegment(value: false, label: Text(AppStrings.t('文字')), icon: Icon(Icons.notes, size: 16)),
                ],
                selected: {isLink},
                onSelectionChanged: (v) => setDialog(() => isLink = v.first),
              ),
              SizedBox(height: 14),
              TextField(
                controller: labelCtl,
                decoration: InputDecoration(
                  labelText: AppStrings.t('名称'),
                  hintText: isLink ? AppStrings.t('例如：GitHub 发布页') : AppStrings.t('例如：朋友分享的安装包'),
                ),
              ),
              if (isLink) ...[
                SizedBox(height: 12),
                TextField(
                  controller: urlCtl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('链接'),
                    hintText: AppStrings.t('https://… 或 tg://、quark:// 等'),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t('取消'))),
            FilledButton(
              onPressed: () {
                final label = labelCtl.text.trim();
                if (label.isEmpty) return;
                var url = isLink ? urlCtl.text.trim() : null;
                if (isLink && (url == null || url.isEmpty)) return;
                if (isLink && !url!.contains('://')) url = 'https://$url';
                if (existing == null) {
                  s.addSource(app.id, label, url);
                } else {
                  s.updateSource(AppSource(
                      id: existing.id, appId: app.id, label: label, url: url));
                }
                Navigator.pop(ctx);
              },
              child: Text(AppStrings.t('保存')),
            ),
          ],
        ),
      ),
    );
  }
}
