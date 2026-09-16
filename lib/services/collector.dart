import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../data/db.dart';
import '../data/models.dart';
import 'native_bridge.dart';

class CollectResult {
  final int newApps;
  final int daysChanged;
  final String? error;
  const CollectResult({this.newApps = 0, this.daysChanged = 0, this.error});
}

/// 负责从系统读取使用记录并入库；应用发现 / 卸载保留 / 重装叠加。
class UsageCollector {
  final AppDatabase db;
  final NativeBridge native;
  UsageCollector(this.db, this.native);

  String get _device => db.deviceId;

  /// 同步已安装应用清单：新装自动进“未分类”；卸载标记保留数据；重装叠加。
  /// 注意：较重（全量枚举 + 逐应用 SQL），由 [refreshAppsIfStale] 低频调用。
  Future<int> refreshInstalledApps() async {
    if (!native.isAndroid) return 0;
    final installed = await native.getInstalledApps();
    final now = DateTime.now().millisecondsSinceEpoch;
    final currentPackages = <String>{};
    var newCount = 0;

    // 一次取回现有清单建索引，避免循环里逐应用 SELECT
    final byKey = <String, AppEntry>{
      for (final a in db.allApps(platform: 'android')) '${a.platform}|${a.package}': a,
    };

    for (final m in installed) {
      final pkg = m['package'] as String?;
      if (pkg == null) continue;
      currentPackages.add(pkg);
      final name = (m['name'] as String?) ?? pkg;
      final installMs = m['installMs'] as int?;
      final isSystem = (m['isSystem'] as bool?) == true ? 1 : 0;
      final iconPath = m['iconPath'] as String?;

      final existing = byKey['android|$pkg'];
      if (existing == null) {
        db.insertApp(AppEntry(
          id: 0,
          package: pkg,
          platform: 'android',
          name: name,
          installDateMs: installMs,
          firstSeenMs: now,
          lastSeenMs: now,
          isSystem: isSystem,
          iconPath: iconPath,
        ));
        newCount++;
      } else {
        final wasUninstalled = existing.uninstalled == 1;
        db.updateApp(existing.copyWith(
          name: name,
          iconPath: iconPath ?? existing.iconPath,
          isSystem: isSystem,
          uninstalled: 0,
          reinstallCount: wasUninstalled ? existing.reinstallCount + 1 : null,
          lastSeenMs: now,
        ));
        byKey['android|$pkg'] = existing.copyWith(uninstalled: 0);
      }
    }

    // 标记已卸载（数据不删）
    for (final a in byKey.values) {
      if (!currentPackages.contains(a.package) && a.uninstalled == 0) {
        db.updateApp(a.copyWith(uninstalled: 1, lastSeenMs: now));
      }
    }
    db.setSetting('last_refresh_ms', now.toString());
    return newCount;
  }

  /// 低频刷新应用清单：距上次 ≥5 分钟才执行（防卡顿核心）。
  Future<int> refreshAppsIfStale() async {
    if (!native.isAndroid) return 0;
    final last = int.tryParse(db.getSetting('last_refresh_ms') ?? '') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last < 5 * 60 * 1000) return 0;
    return refreshInstalledApps();
  }

  /// 增量采集近期数据（App 在前台时周期调用）。
  Future<CollectResult> collectRecent() async {
    try {
      if (native.isAndroid) {
        return await _collectAndroid();
      } else if (native.isWindows) {
        return await _collectWindows();
      }
      return const CollectResult();
    } catch (e) {
      debugPrint('collectRecent error: $e');
      return CollectResult(error: e.toString());
    }
  }

  Future<CollectResult> _collectAndroid() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final anchorStr = db.getSetting('last_collect_ms');
    var anchor = anchorStr == null
        ? DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch
        : int.tryParse(anchorStr) ?? now;
    anchor = max(anchor, DateTime.now().subtract(const Duration(days: 400)).millisecondsSinceEpoch);

    // 1) 日桶统计（权威）
    final stats = await native.getDailyStats(anchor, now);
    var changed = 0;
    for (final s in stats) {
      final pkg = s['package'] as String?;
      final dayStart = s['dayStartMs'] as int?;
      final total = (s['totalMs'] as num?)?.toInt() ?? 0;
      if (pkg == null || dayStart == null || total <= 0) continue;
      final app = db.findApp(pkg, 'android');
      if (app == null) continue;
      final day = DayX.keyOf(DateTime.fromMillisecondsSinceEpoch(dayStart));
      if (db.mergeDaily(app.id, _device, day, total, now)) changed++;
    }

    // 2) 近 3 天事件片段（时间轴）：最多每 15 分钟拉一次，避免频繁重写 sessions
    final lastEvents = int.tryParse(db.getSetting('last_events_ms') ?? '') ?? 0;
    if (now - lastEvents >= 15 * 60 * 1000) {
      final evStart = DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch;
      final events = await native.getEvents(evStart, now);
      db.deleteSessionsBetween(evStart, now);
      final batch = <UsageSession>[];
      for (final e in events) {
        final pkg = e['package'] as String?;
        final st = e['startMs'] as int?;
        final en = e['endMs'] as int?;
        if (pkg == null || st == null || en == null || en <= st) continue;
        final app = db.findApp(pkg, 'android');
        if (app == null) continue;
        for (final seg in _splitByDay(st, en)) {
          batch.add(UsageSession(
              appId: app.id, deviceId: _device, startMs: seg.$1, endMs: seg.$2));
        }
      }
      db.insertSessionsBatch(batch);
      db.pruneSessions(DateTime.now().subtract(const Duration(days: 31)).millisecondsSinceEpoch);
      db.setSetting('last_events_ms', now.toString());
    }

    db.setSetting('last_collect_ms', now.toString());
    return CollectResult(daysChanged: changed);
  }

  Future<CollectResult> _collectWindows() async {
    await native.startTracking();
    final sessions = await native.pullForegroundSessions();
    if (sessions.isEmpty) return const CollectResult();
    final now = DateTime.now().millisecondsSinceEpoch;
    var newCount = 0;
    final toInsert = <UsageSession>[];

    for (final s in sessions) {
      final exe = s['exe'] as String?;
      final st = s['startMs'] as int?;
      final en = s['endMs'] as int?;
      if (exe == null || st == null || en == null || en <= st) continue;
      var app = db.findApp(exe, 'windows');
      if (app == null) {
        final name = (s['name'] as String?) ?? exe.split(r'\').last;
        final id = db.insertApp(AppEntry(
          id: 0,
          package: exe,
          platform: 'windows',
          name: name,
          installDateMs: null,
          firstSeenMs: st,
          lastSeenMs: now,
          iconPath: s['iconPath'] as String?,
        ));
        app = db.appById(id);
        newCount++;
      }
      for (final seg in _splitByDay(st, en)) {
        toInsert.add(UsageSession(
            appId: app.id, deviceId: _device, startMs: seg.$1, endMs: seg.$2));
        final day = DayX.keyOf(DateTime.fromMillisecondsSinceEpoch(seg.$1));
        final existing = db.dailyTotals(app.id, day, day)[day] ?? 0;
        db.mergeDaily(app.id, _device, day, existing + (seg.$2 - seg.$1), now);
      }
    }
    db.insertSessionsBatch(toInsert);
    db.pruneSessions(DateTime.now().subtract(const Duration(days: 31)).millisecondsSinceEpoch);
    return CollectResult(newApps: newCount, daysChanged: toInsert.length);
  }

  /// 一次性导入系统里保留的全部历史使用记录（日桶）。
  Future<CollectResult> importHistory({ValueChanged<String>? onProgress}) async {
    if (!native.isAndroid) {
      return const CollectResult(error: 'Windows 端无系统历史数据，将从安装本软件起开始记录');
    }
    try {
      await refreshInstalledApps();
      onProgress?.call('正在读取系统历史记录…');
      // 系统保留约一年左右的日聚合，一次拉取
      final begin = DateTime.now().subtract(const Duration(days: 1100)).millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      final stats = await native.getDailyStats(begin, now);
      var changed = 0;
      for (final s in stats) {
        final pkg = s['package'] as String?;
        final dayStart = s['dayStartMs'] as int?;
        final total = (s['totalMs'] as num?)?.toInt() ?? 0;
        if (pkg == null || dayStart == null || total <= 1000) continue;
        var app = db.findApp(pkg, 'android');
        app ??= db.appById(db.insertApp(AppEntry(
          id: 0,
          package: pkg,
          platform: 'android',
          name: pkg,
          firstSeenMs: dayStart,
          lastSeenMs: now,
          uninstalled: 1, // 历史里出现但当前未安装的应用，稍后由清单校正
        )));
        final day = DayX.keyOf(DateTime.fromMillisecondsSinceEpoch(dayStart));
        if (db.mergeDaily(app.id, _device, day, total, now)) changed++;
      }
      // 用当前清单校正名称 / 安装状态 / 安装日期
      await refreshInstalledApps();
      db.setSetting('history_imported', '1');
      db.setSetting('last_collect_ms', now.toString());
      return CollectResult(daysChanged: changed);
    } catch (e) {
      return CollectResult(error: e.toString());
    }
  }

  /// 把限额表下发给原生监控服务。
  Future<void> pushLimits() async {
    if (!native.isAndroid) return;
    final map = <String, int>{};
    for (final a in db.allApps(platform: 'android')) {
      if (a.dailyLimitMinutes != null && a.dailyLimitMinutes! > 0) {
        map[a.package] = a.dailyLimitMinutes!;
      }
    }
    await native.pushLimits(map);
  }

  /// 把跨午夜的片段切成按天的多段。返回 (startMs,endMs) 列表。
  static List<(int, int)> _splitByDay(int startMs, int endMs) {
    final startDay = DayX.dateOnly(DateTime.fromMillisecondsSinceEpoch(startMs));
    final endDay = DayX.dateOnly(DateTime.fromMillisecondsSinceEpoch(endMs));
    if (startDay == endDay) return [(startMs, endMs)];
    final result = <(int, int)>[];
    var cursor = startMs;
    var day = startDay;
    while (day.isBefore(endDay)) {
      final nextStart = day.add(const Duration(days: 1)).millisecondsSinceEpoch;
      result.add((cursor, nextStart));
      cursor = nextStart;
      day = day.add(const Duration(days: 1));
    }
    result.add((cursor, endMs));
    return result;
  }
}
