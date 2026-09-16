import 'dart:io';

import 'package:flutter/services.dart';

/// 原生能力统一通道（Android UsageStats / Windows 前台窗口追踪）。
class NativeBridge {
  static const _ch = MethodChannel('com.screenjournal.app/native');

  bool get isAndroid => Platform.isAndroid;
  bool get isWindows => Platform.isWindows;
  String get platformName => isAndroid ? 'android' : (isWindows ? 'windows' : 'other');

  Future<T?> _invoke<T>(String method, [Object? args]) {
    return _ch.invokeMethod<T>(method, args);
  }

  // ---------------- 权限（Android） ----------------
  Future<bool> hasUsagePermission() async =>
      isAndroid ? await _invoke<bool>('hasUsagePermission') ?? false : true;

  Future<void> requestUsagePermission() => _invoke('requestUsagePermission');

  Future<bool> isIgnoringBattery() async =>
      isAndroid ? await _invoke<bool>('isIgnoringBattery') ?? false : true;

  Future<void> requestIgnoreBattery() => _invoke('requestIgnoreBattery');

  Future<bool> canDrawOverlays() async =>
      isAndroid ? await _invoke<bool>('canDrawOverlays') ?? false : true;

  Future<void> requestOverlayPermission() => _invoke('requestOverlayPermission');

  Future<bool> isAccessibilityEnabled() async =>
      isAndroid ? await _invoke<bool>('isAccessibilityEnabled') ?? false : false;

  Future<void> openAccessibilitySettings() => _invoke('openAccessibilitySettings');

  Future<bool> notificationsEnabled() async =>
      isAndroid ? await _invoke<bool>('notificationsEnabled') ?? true : true;

  Future<void> openNotificationSettings() => _invoke('openNotificationSettings');

  /// 厂商自启动设置（没有则打开应用详情页）
  Future<void> openAutoStartSettings() => _invoke('openAutoStartSettings');

  // ---------------- 应用清单 / 图标 ----------------

  /// 返回 [{package,name,isSystem,installMs,iconPath}]，并把图标写入缓存。
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final r = await _invoke<List>('getInstalledApps') ?? const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 请求原生侧把某应用图标刷新到缓存，返回路径。
  Future<String?> ensureIcon(String package) async {
    if (isWindows) return null;
    return _invoke<String>('ensureIcon', package);
  }

  // ---------------- Android 使用记录 ----------------

  /// 日桶统计：[{package, dayStartMs, totalMs}]（系统权威数据）
  Future<List<Map<String, dynamic>>> getDailyStats(int startMs, int endMs) async {
    if (!isAndroid) return const [];
    final r = await _invoke<List>('getDailyStats',
        <String, int>{'start': startMs, 'end': endMs}) ?? const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// 前台事件片段：[{package,startMs,endMs}]（近 7 天，用于时间轴）
  Future<List<Map<String, dynamic>>> getEvents(int startMs, int endMs) async {
    if (!isAndroid) return const [];
    final r = await _invoke<List>('getEvents',
        <String, int>{'start': startMs, 'end': endMs}) ?? const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------------- 实时监控服务 / 限额 ----------------
  Future<void> startMonitor() => _invoke('startMonitor');
  Future<void> stopMonitor() => _invoke('stopMonitor');
  Future<bool> isMonitorRunning() async =>
      isAndroid ? await _invoke<bool>('isMonitorRunning') ?? false : false;

  /// 下发限额表 {package: minutes}，null/0 表示取消
  Future<void> pushLimits(Map<String, int> limits) => _invoke('pushLimits', limits);

  /// 回到桌面（Android 经无障碍；Windows 最小化所有窗口）
  Future<void> minimizeToHome() => _invoke('minimizeToHome');

  // ---------------- Windows 前台追踪 ----------------
  Future<void> startTracking({int intervalSeconds = 5}) =>
      _invoke('startTracking', intervalSeconds);

  /// 取出并清空原生侧缓冲的前台片段 [{exe,name,startMs,endMs,iconPath}]
  Future<List<Map<String, dynamic>>> pullForegroundSessions() async {
    if (!isWindows) return const [];
    final r = await _invoke<List>('pullForegroundSessions') ?? const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> setAutoStart(bool on) async {
    if (isWindows) await _invoke('setAutoStart', on);
  }

  Future<bool> getAutoStart() async =>
      isWindows ? await _invoke<bool>('getAutoStart') ?? false : false;

  /// 设备显示名（Android 品牌型号 / Windows 计算机名）
  Future<String> getDeviceName() async {
    try {
      return await _invoke<String>('getDeviceName') ?? '我的设备';
    } catch (_) {
      return Platform.isWindows ? Platform.environment['COMPUTERNAME'] ?? 'Windows 电脑' : '我的设备';
    }
  }
}
