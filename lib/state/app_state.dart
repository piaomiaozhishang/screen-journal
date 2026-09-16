import 'dart:async';

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/collector.dart';
import '../services/native_bridge.dart';
import '../services/stats.dart';
import '../services/sync_backup.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  late final AppDatabase db;
  late final NativeBridge native;
  late final UsageCollector collector;
  late final StatsService stats;
  late final DataService dataService;

  bool ready = false;
  String? initError;
  Timer? _periodic;
  bool _collecting = false;

  Future<void> init() async {
    try {
      db = await AppDatabase.open();
      native = NativeBridge();
      collector = UsageCollector(db, native);
      stats = StatsService(db);
      dataService = DataService(db);
      WidgetsBinding.instance.addObserver(this);
      _seedDefaults();
      if (native.isWindows) {
        await native.startTracking();
      }
      if (native.isAndroid && monitorEnabled) {
        await native.startMonitor();
      }
      await collectNow(silent: true);
      // 应用清单刷新较重，放后台延迟执行，不阻塞首屏
      Future<void>.delayed(const Duration(seconds: 2), () async {
        try {
          await collector.refreshAppsIfStale();
          notifyListeners();
        } catch (e) {
          debugPrint('background refresh error: $e');
        }
      });
      _periodic = Timer.periodic(const Duration(seconds: 30), (_) async {
        await collectNow(silent: true);
        try {
          await collector.refreshAppsIfStale();
        } catch (e) {
          debugPrint('periodic refresh error: $e');
        }
      });
      ready = true;
      notifyListeners();
    } catch (e, st) {
      initError = '$e\n$st';
      debugPrint('AppState.init error: $e\n$st');
      notifyListeners();
    }
  }

  void _seedDefaults() {
    if (db.getSetting('seeded') == '1') return;
    final defs = <(String, int, IconData)>[
      ('游戏', 0xFF7E57C2, Icons.sports_esports),
      ('小说', 0xFF8D6E63, Icons.auto_stories),
      ('动漫', 0xFFEC407A, Icons.animation),
      ('影视', 0xFF42A5F5, Icons.movie),
    ];
    for (var i = 0; i < defs.length; i++) {
      final d = defs[i];
      db.insertCategory(d.$1, d.$2, d.$3.codePoint, i);
    }
    db.setSetting('seeded', '1');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      collectNow(); // 回到前台刷新界面
      collector.refreshAppsIfStale().catchError((e) {
        debugPrint('resumed refresh error: $e');
        return 0;
      });
    }
  }

  // ---------------- 采集 ----------------
  /// [silent] 为 true 时不触发 UI 重建（周期后台采集用，避免频繁重算页面）。
  Future<CollectResult> collectNow({bool silent = false}) async {
    if (_collecting) return const CollectResult();
    _collecting = true;
    try {
      final r = await collector.collectRecent();
      if (!silent) notifyListeners();
      return r;
    } finally {
      _collecting = false;
    }
  }

  Future<CollectResult> importHistory() async {
    final r = await collector.importHistory();
    notifyListeners();
    return r;
  }

  // ---------------- 分类 ----------------
  List<Category> get categories => db.allCategories();

  int saveCategory(
      {int? id,
      required String name,
      required int color,
      required int icon,
      String? iconPath}) {
    if (id == null) {
      final order = db.allCategories().length;
      final newId = db.insertCategory(name, color, icon, order, iconPath: iconPath);
      notifyListeners();
      return newId;
    } else {
      final old = db.allCategories().firstWhere((c) => c.id == id);
      db.updateCategory(old.copyWith(
          name: name, colorValue: color, iconCodePoint: icon, iconPath: iconPath));
      notifyListeners();
      return id;
    }
  }

  void deleteCategory(int id) {
    db.deleteCategory(id); // app_categories 级联，应用自动回到未分类
    notifyListeners();
  }

  List<AppEntry> appsOfCategory(int? categoryId, {String? platform}) =>
      categoryId == null
          ? db.uncategorizedApps(platform: platform)
          : db.appsOfCategory(categoryId, platform: platform);

  void setAppCategories(int appId, List<int> ids) {
    db.setAppCategories(appId, ids);
    notifyListeners();
  }

  void toggleAppCategory(int appId, int categoryId, bool on) {
    db.toggleAppCategory(appId, categoryId, on);
    notifyListeners();
  }

  /// 批量：把选中的应用归入某分类，未选中的移出该分类（保留其他标签）。
  void setAppCategoriesBulk(int categoryId, Set<int> selectedAppIds) {
    for (final a in db.allApps()) {
      final has = db.categoryIdsOfApp(a.id).contains(categoryId);
      final should = selectedAppIds.contains(a.id);
      if (should && !has) db.toggleAppCategory(a.id, categoryId, true);
      if (!should && has) db.toggleAppCategory(a.id, categoryId, false);
    }
    notifyListeners();
  }

  List<int> categoryIdsOfApp(int appId) => db.categoryIdsOfApp(appId);

  // ---------------- 应用元信息 ----------------
  void updateApp(AppEntry updated) {
    db.updateApp(updated);
    collector.pushLimits();
    if (native.isAndroid && monitorEnabled) native.startMonitor();
    notifyListeners();
  }

  List<AppEntry> allApps({String? platform}) => db.allApps(platform: platform);
  AppEntry appById(int id) => db.appById(id);

  List<AppSource> sourcesOf(int appId) => db.sourcesOfApp(appId);
  void addSource(int appId, String label, String? url) {
    db.addSource(appId, label, url);
    notifyListeners();
  }

  void updateSource(AppSource s) {
    db.updateSource(s);
    notifyListeners();
  }

  void deleteSource(int id) {
    db.deleteSource(id);
    notifyListeners();
  }

  // ---------------- 引导 / 监控 ----------------
  bool get onboardingDone => db.getSetting('onboarding_done') == '1';
  void setOnboardingDone() {
    db.setSetting('onboarding_done', '1');
    notifyListeners();
  }

  bool get monitorEnabled => db.getSetting('monitor_enabled') == '1';
  Future<void> setMonitorEnabled(bool on) async {
    db.setSetting('monitor_enabled', on ? '1' : '0');
    if (native.isAndroid) {
      if (on) {
        await native.startMonitor();
      } else {
        await native.stopMonitor();
      }
    }
    notifyListeners();
  }

  bool get autoStartWindows => false; // 实际值异步读
  Future<bool> readWindowsAutoStart() => native.getAutoStart();
  Future<void> setWindowsAutoStart(bool on) => native.setAutoStart(on);

  /// 当前版本号（与 pubspec version 保持一致）
  static const String appVersion = '1.0.4';

  // ---------------- 外观：主题 ----------------
  ThemeMode get themeMode => switch (db.getSetting('theme_mode') ?? 'system') {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  int get themeSeed =>
      int.tryParse(db.getSetting('theme_seed') ?? '') ?? 0xFF1F9E89;

  void setThemeMode(ThemeMode m) {
    db.setSetting('theme_mode',
        m == ThemeMode.light ? 'light' : (m == ThemeMode.dark ? 'dark' : 'system'));
    notifyListeners();
  }

  void setThemeSeed(int v) {
    db.setSetting('theme_seed', v.toString());
    notifyListeners();
  }

  // ---------------- 语言 ----------------
  String get appLanguage => db.getSetting('language') ?? 'system';

  void setAppLanguage(String lang) {
    db.setSetting('language', lang);
    notifyListeners();
  }

  // ---------------- WebDAV 配置 ----------------
  String? get webdavUrl => db.getSetting('webdav_url');
  String? get webdavUser => db.getSetting('webdav_user');
  String? get webdavPassword => db.getSetting('webdav_password');
  String get webdavRoot => db.getSetting('webdav_root') ?? 'screentime';
  String get deviceName => db.getSetting('device_name') ?? '我的设备';
  String get deviceId => db.deviceId;

  void saveWebDavConfig({String? url, String? user, String? password, String? root, String? name}) {
    if (url != null) db.setSetting('webdav_url', url.trim());
    if (user != null) db.setSetting('webdav_user', user.trim());
    if (password != null) db.setSetting('webdav_password', password);
    if (root != null && root.trim().isNotEmpty) db.setSetting('webdav_root', root.trim());
    if (name != null && name.trim().isNotEmpty) db.setSetting('device_name', name.trim());
    notifyListeners();
  }

  String? get lastSyncMs => db.getSetting('last_sync_ms');
  bool get historyImported => db.getSetting('history_imported') == '1';

  Future<SyncReport> syncWebDav() {
    return dataService.syncViaWebDav(
      url: webdavUrl ?? '',
      username: webdavUser ?? '',
      password: webdavPassword ?? '',
      deviceName: deviceName,
      platform: native.platformName,
      root: webdavRoot,
    ).whenComplete(notifyListeners);
  }

  Future<String?> exportBackup() => dataService.exportToFile(deviceName);

  Future<Map<String, int>?> importBackup({bool overwrite = false}) async {
    final r = await dataService.importFromFile(overwrite: overwrite);
    notifyListeners();
    return r;
  }

  @override
  void dispose() {
    _periodic?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
