/// 时长 / 数字的人性化格式化。
class Fmt {
  /// 12小时30分 / 1小时05分 / 45分 / 1分20秒 / 35秒
  static String duration(Duration d) {
    final totalSec = d.inSeconds;
    if (totalSec < 60) return '$totalSec秒';
    final m = totalSec ~/ 60;
    if (m < 60) {
      final sec = totalSec % 60;
      return sec == 0 ? '$m分' : '$m分$sec秒';
    }
    final h = m ~/ 60;
    final mm = m % 60;
    if (h < 24) return mm == 0 ? '$h小时' : '$h小时$mm分';
    final days = h ~/ 24;
    final hh = h % 24;
    return hh == 0 ? '$days天' : '$days天$hh小时';
  }

  /// 紧凑格式：12.5h / 45m / 35s（图表、排行用）
  static String compact(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    if (m < 60) return '${m}m';
    final h = m / 60;
    if (h < 24) return '${h.toStringAsFixed(h >= 10 ? 0 : 1)}h';
    return '${(h / 24).toStringAsFixed(1)}d';
  }

  static String hours(double h) {
    if (h < 1) return '${(h * 60).round()}分钟';
    return '${h.toStringAsFixed(1)} 小时';
  }

  static String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String dateCn(DateTime d) => '${d.year}年${d.month}月${d.day}日';
}
