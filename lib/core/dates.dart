import 'package:intl/intl.dart';

import 'l10n.dart';

/// 日期工具：本应用所有“天”均按设备本地时区切分，一周从周一开始。
class DayX {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String keyOf(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  static DateTime parseKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// 本周一 00:00
  static DateTime startOfWeek(DateTime d) {
    final d0 = dateOnly(d);
    return d0.subtract(Duration(days: (d0.weekday - DateTime.monday) % 7));
  }

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime startOfYear(DateTime d) => DateTime(d.year, 1, 1);

  static int diffInDays(DateTime a, DateTime b) =>
      dateOnly(a).difference(dateOnly(b)).inDays;

  /// 区间内包含的每一天 key（含首尾）
  static List<String> dayKeysBetween(DateTime start, DateTime endInclusive) {
    final s = dateOnly(start);
    final e = dateOnly(endInclusive);
    final days = e.difference(s).inDays;
    return List.generate(days + 1, (i) => keyOf(s.add(Duration(days: i))));
  }
}

enum TimeRange { day, week, month, year, forever }

extension TimeRangeX on TimeRange {
  String get label => switch (this) {
        TimeRange.day => AppStrings.t('日'),
        TimeRange.week => AppStrings.t('周'),
        TimeRange.month => AppStrings.t('月'),
        TimeRange.year => AppStrings.t('年'),
        TimeRange.forever => AppStrings.t('永久'),
      };

  /// 该区间的起始时间（本地时区 00:00）；永久返回 null
  DateTime? start(DateTime now) => switch (this) {
        TimeRange.day => DayX.dateOnly(now),
        TimeRange.week => DayX.startOfWeek(now),
        TimeRange.month => DayX.startOfMonth(now),
        TimeRange.year => DayX.startOfYear(now),
        TimeRange.forever => null,
      };

  /// 对比视图中上一周期的起止（forever 无对比）
  (DateTime, DateTime)? previousPeriod(DateTime now) {
    switch (this) {
      case TimeRange.day:
        final y = DayX.dateOnly(now).subtract(const Duration(days: 1));
        return (y, y);
      case TimeRange.week:
        final s = DayX.startOfWeek(now);
        final ps = s.subtract(const Duration(days: 7));
        return (ps, s.subtract(const Duration(days: 1)));
      case TimeRange.month:
        final s = DayX.startOfMonth(now);
        final ps = DateTime(s.year, s.month - 1, 1);
        return (ps, s.subtract(const Duration(days: 1)));
      case TimeRange.year:
        final s = DayX.startOfYear(now);
        final ps = DateTime(s.year - 1, 1, 1);
        return (ps, s.subtract(const Duration(days: 1)));
      case TimeRange.forever:
        return null;
    }
  }
}
