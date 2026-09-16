// 基础纯逻辑冒烟测试（不依赖平台通道）。
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_journal/core/dates.dart';
import 'package:screen_time_journal/core/format.dart';

void main() {
  test('DayX 日期键与解析', () {
    final d = DateTime(2026, 9, 16, 15, 30);
    expect(DayX.keyOf(d), '2026-09-16');
    expect(DayX.parseKey('2026-09-16'), DateTime(2026, 9, 16));
    expect(DayX.dateOnly(d), DateTime(2026, 9, 16));
  });

  test('周一起始', () {
    // 2026-09-16 是周三，本周周一应为 2026-09-14
    final ws = DayX.startOfWeek(DateTime(2026, 9, 16));
    expect(ws, DateTime(2026, 9, 14));
  });

  test('时长格式化', () {
    expect(Fmt.duration(Duration.zero), '0秒');
    expect(Fmt.duration(const Duration(hours: 1)), '1小时');
    expect(Fmt.duration(const Duration(hours: 1, minutes: 25)), '1小时25分');
    expect(Fmt.duration(const Duration(minutes: 45)), '45分');
  });
}
