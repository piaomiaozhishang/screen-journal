import '../core/dates.dart';
import '../data/db.dart';
import '../data/models.dart';

/// 单日使用达到该时长才算“使用日”（用于连续天数）。
const int kStreakThresholdMs = 60 * 1000;

class AppStats {
  final int totalMs;
  final int activeDays;
  final int avgPerDayMs; // 永久总量 / 记录覆盖天数
  final int currentStreak;
  final int longestStreak;
  final int maxDailyMs;
  final String? maxDailyDay;
  final String? firstDay;

  const AppStats({
    required this.totalMs,
    required this.activeDays,
    required this.avgPerDayMs,
    required this.currentStreak,
    required this.longestStreak,
    required this.maxDailyMs,
    this.maxDailyDay,
    this.firstDay,
  });
}

class StatsService {
  final AppDatabase db;
  StatsService(this.db);

  /// 某应用在某天的总时长（跨设备）
  int totalOnDay(int appId, DateTime day) {
    final k = DayX.keyOf(day);
    return db.dailyTotals(appId, k, k)[k] ?? 0;
  }

  /// 区间总量（forever 时 startKey 传 '0000-01-01'）
  int rangeTotal(int appId, TimeRange range, DateTime now) {
    final start = range.start(now);
    final startKey = start == null ? '0000-01-01' : DayX.keyOf(start);
    final endKey = DayX.keyOf(now);
    return db.dailyTotals(appId, startKey, endKey).values.fold<int>(0, (a, b) => a + b);
  }

  /// 区间内每日序列（补齐空白天）
  List<MapEntry<String, int>> dailySeries(
      int? appId, DateTime start, DateTime endInclusive) {
    final keys = DayX.dayKeysBetween(start, endInclusive);
    final Map<String, int> data = appId == null
        ? _globalDaily(keys.first, keys.last)
        : db.dailyTotals(appId, keys.first, keys.last);
    return keys.map((k) => MapEntry(k, data[k] ?? 0)).toList();
  }

  Map<String, int> _globalDaily(String startKey, String endKey) {
    final r = db.db.select(
      'SELECT day, SUM(time_ms) t FROM daily_usage WHERE day>=? AND day<=? GROUP BY day',
      [startKey, endKey],
    );
    return {for (final row in r) row['day'] as String: row['t'] as int};
  }

  /// 永久统计：平均、连续、峰值
  AppStats appStats(int appId) {
    final all = db.dailyTotals(appId, '0000-01-01', '9999-12-31');
    final total = all.values.fold<int>(0, (a, b) => a + b);
    final usedDays = all.keys.where((k) => (all[k] ?? 0) >= kStreakThresholdMs).toList()
      ..sort();
    final activeDays = usedDays.length;
    final firstDay = usedDays.isEmpty ? null : usedDays.first;
    final spanDays = firstDay == null
        ? 0
        : DayX.diffInDays(DateTime.now(), DayX.parseKey(firstDay)) + 1;
    final avg = spanDays <= 0 ? 0 : (total / spanDays).round();

    var maxDaily = 0;
    String? maxDay;
    all.forEach((k, v) {
      if (v > maxDaily) {
        maxDaily = v;
        maxDay = k;
      }
    });

    final longest = _longestStreak(usedDays);
    final current = _currentStreak(usedDays);
    return AppStats(
      totalMs: total,
      activeDays: activeDays,
      avgPerDayMs: avg,
      currentStreak: current,
      longestStreak: longest,
      maxDailyMs: maxDaily,
      maxDailyDay: maxDay,
      firstDay: firstDay,
    );
  }

  int _longestStreak(List<String> daysAsc) {
    if (daysAsc.isEmpty) return 0;
    var best = 1, cur = 1;
    for (var i = 1; i < daysAsc.length; i++) {
      final d = DayX.parseKey(daysAsc[i]);
      final p = DayX.parseKey(daysAsc[i - 1]);
      if (DayX.diffInDays(d, p) == 1) {
        cur++;
      } else {
        cur = 1;
      }
      if (cur > best) best = cur;
    }
    return best;
  }

  int _currentStreak(List<String> daysAsc) {
    if (daysAsc.isEmpty) return 0;
    final set = daysAsc.toSet();
    final today = DayX.dateOnly(DateTime.now());
    var anchor = today;
    // 今天还没用时，不断 streak，从昨天起算
    if (!set.contains(DayX.keyOf(today))) {
      anchor = today.subtract(const Duration(days: 1));
      if (!set.contains(DayX.keyOf(anchor))) return 0;
    }
    var n = 0;
    while (set.contains(DayX.keyOf(anchor))) {
      n++;
      anchor = anchor.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// 首页：区间内分类占比。多标签应用在每个标签下各计一次；未分类单列。
  /// [customStart]/[customEnd] 非空时使用自定义区间（忽略 range/now）。
  List<CategorySlice> categorySlices(TimeRange range, DateTime now,
      {String? platform, DateTime? customStart, DateTime? customEnd}) {
    final startKey = customStart != null
        ? DayX.keyOf(customStart)
        : (range.start(now) == null ? '0000-01-01' : DayX.keyOf(range.start(now)!));
    final endKey = DayX.keyOf(customEnd ?? now);
    final rows = db.totalsPerAppBetween(startKey, endKey, platform: platform);
    final catById = {for (final c in db.allCategories()) c.id: c};
    final catMap = db.appCategoryMap();
    final totals = <int, int>{};
    var uncategorized = 0;
    for (final r in rows) {
      final t = r['t'] as int;
      final appId = r['id'] as int;
      final cats = catMap[appId] ?? const <int>[];
      if (cats.isEmpty) {
        uncategorized += t;
      } else {
        for (final c in cats) {
          totals[c] = (totals[c] ?? 0) + t;
        }
      }
    }
    final slices = <CategorySlice>[];
    totals.forEach((cid, t) {
      final c = catById[cid];
      if (c != null) slices.add(CategorySlice(category: c, timeMs: t));
    });
    if (uncategorized > 0) slices.add(CategorySlice.uncategorized(uncategorized));
    slices.sort((a, b) => b.timeMs.compareTo(a.timeMs));
    return slices;
  }

  /// 区间内应用排行
  List<AppTotal> ranking(TimeRange range, DateTime now,
      {String? platform, int? categoryId, bool uncategorizedOnly = false, int limit = 100,
      DateTime? customStart, DateTime? customEnd}) {
    final startKey = customStart != null
        ? DayX.keyOf(customStart)
        : (range.start(now) == null ? '0000-01-01' : DayX.keyOf(range.start(now)!));
    final endKey = DayX.keyOf(customEnd ?? now);
    final rows = db.totalsPerAppBetween(startKey, endKey, platform: platform);
    final catMap = db.appCategoryMap();
    final result = <AppTotal>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final cats = catMap[id] ?? const <int>[];
      if (uncategorizedOnly) {
        if (cats.isNotEmpty) continue;
      } else if (categoryId != null) {
        if (!cats.contains(categoryId)) continue;
      }
      result.add(AppTotal(
        appId: id,
        package: r['package'] as String,
        name: r['name'] as String,
        platform: r['platform'] as String,
        uninstalled: (r['uninstalled'] as int?) ?? 0,
        iconPath: r['icon_path'] as String?,
        timeMs: r['t'] as int,
      ));
    }
    result.sort((a, b) => b.timeMs.compareTo(a.timeMs));
    return result.take(limit).toList();
  }

  /// 对比：本周期 vs 上周期，返回每应用两期时长
  CompareResult compare(TimeRange range, DateTime now, {String? platform}) {
    final prev = range.previousPeriod(now);
    if (prev == null) {
      return const CompareResult(currentTotal: 0, previousTotal: 0, items: []);
    }
    final curStart = range.start(now)!;
    final curRows = db.totalsPerAppBetween(DayX.keyOf(curStart), DayX.keyOf(now),
        platform: platform);
    final prevRows = db.totalsPerAppBetween(
        DayX.keyOf(prev.$1), DayX.keyOf(prev.$2),
        platform: platform);
    final map = <int, Map<String, Object?>>{};
    var curTotal = 0, prevTotal = 0;
    for (final r in curRows) {
      map[r['id'] as int] = {
        'id': r['id'], 'name': r['name'], 'package': r['package'],
        'platform': r['platform'], 'uninstalled': r['uninstalled'],
        'icon_path': r['icon_path'], 'cur': r['t'] as int, 'prev': 0,
      };
      curTotal += r['t'] as int;
    }
    for (final r in prevRows) {
      final e = map[r['id'] as int];
      if (e != null) {
        e['prev'] = r['t'] as int;
      } else {
        map[r['id'] as int] = {
          'id': r['id'], 'name': r['name'], 'package': r['package'],
          'platform': r['platform'], 'uninstalled': r['uninstalled'],
          'icon_path': r['icon_path'], 'cur': 0, 'prev': r['t'] as int,
        };
      }
      prevTotal += r['t'] as int;
    }
    final items = map.values
        .map((m) => CompareItem(
              appId: m['id'] as int,
              name: m['name'] as String,
              package: m['package'] as String,
              platform: m['platform'] as String,
              uninstalled: (m['uninstalled'] as int?) ?? 0,
              iconPath: m['icon_path'] as String?,
              currentMs: m['cur'] as int,
              previousMs: m['prev'] as int,
            ))
        .toList()
      ..sort((a, b) => (b.currentMs + b.previousMs).compareTo(a.currentMs + a.previousMs));
    return CompareResult(
        currentTotal: curTotal, previousTotal: prevTotal, items: items);
  }
}

class CategorySlice {
  final Category? category; // null=未分类
  final int timeMs;
  const CategorySlice({this.category, required this.timeMs});
  factory CategorySlice.uncategorized(int t) => CategorySlice(timeMs: t);

  String get name => category?.name ?? '未分类';
  int get colorValue => category?.colorValue ?? 0xFF9E9E9E;
  int get iconCodePoint => category?.iconCodePoint ?? 0;
}

class AppTotal {
  final int appId;
  final String package;
  final String name;
  final String platform;
  final int uninstalled;
  final String? iconPath;
  final int timeMs;
  const AppTotal({
    required this.appId,
    required this.package,
    required this.name,
    required this.platform,
    required this.uninstalled,
    this.iconPath,
    required this.timeMs,
  });
}

class CompareItem {
  final int appId;
  final String name;
  final String package;
  final String platform;
  final int uninstalled;
  final String? iconPath;
  final int currentMs;
  final int previousMs;
  const CompareItem({
    required this.appId,
    required this.name,
    required this.package,
    required this.platform,
    required this.uninstalled,
    this.iconPath,
    required this.currentMs,
    required this.previousMs,
  });

  int get deltaMs => currentMs - previousMs;
  double? get ratio =>
      previousMs == 0 ? null : (currentMs - previousMs) / previousMs;
}

class CompareResult {
  final int currentTotal;
  final int previousTotal;
  final List<CompareItem> items;
  const CompareResult(
      {required this.currentTotal, required this.previousTotal, required this.items});

  int get deltaMs => currentTotal - previousTotal;
  double? get ratio =>
      previousTotal == 0 ? null : (currentTotal - previousTotal) / previousTotal;
}
