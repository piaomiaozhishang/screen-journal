import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'models.dart';

/// 全局 SQLite 数据访问。裸 SQL，跨 Android / Windows。
class AppDatabase {
  late final Database db;
  final String deviceId;

  AppDatabase._(this.db, this.deviceId);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = p.join(dir.path, 'screen_time_journal.db');
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA foreign_keys=ON;');
    db.execute('PRAGMA busy_timeout=5000;');
    _migrate(db);
    final inst = AppDatabase._(db, _ensureDeviceId(db));
    return inst;
  }

  static const _dbVersion = 2;

  static void _migrate(Database db) {
    final v =
        db.select('PRAGMA user_version').first.values.first as int;
    if (v >= _dbVersion) return;
    db.execute('BEGIN;');
    try {
      db.execute('''
CREATE TABLE IF NOT EXISTS apps(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  package TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  name TEXT NOT NULL,
  install_date_ms INTEGER,
  first_seen_ms INTEGER NOT NULL,
  last_seen_ms INTEGER NOT NULL,
  is_system INTEGER NOT NULL DEFAULT 0,
  uninstalled INTEGER NOT NULL DEFAULT 0,
  reinstall_count INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  rating REAL,
  daily_limit_minutes INTEGER,
  icon_path TEXT,
  UNIQUE(package, platform)
);''');
      db.execute('''
CREATE TABLE IF NOT EXISTS categories(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color INTEGER NOT NULL,
  icon INTEGER NOT NULL,
  icon_path TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);''');
      db.execute('''
CREATE TABLE IF NOT EXISTS app_categories(
  app_id INTEGER NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY(app_id, category_id)
);''');
      db.execute('''
CREATE TABLE IF NOT EXISTS app_sources(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  app_id INTEGER NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  url TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);''');
      db.execute('''
CREATE TABLE IF NOT EXISTS daily_usage(
  app_id INTEGER NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  day TEXT NOT NULL,
  time_ms INTEGER NOT NULL DEFAULT 0,
  updated_ms INTEGER NOT NULL,
  PRIMARY KEY(app_id, device_id, day)
);''');
      db.execute('''
CREATE TABLE IF NOT EXISTS sessions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  app_id INTEGER NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL
);''');
      db.execute('''
CREATE TABLE IF NOT EXISTS settings(
  k TEXT PRIMARY KEY,
  v TEXT
);''');
      db.execute('CREATE INDEX IF NOT EXISTS idx_daily_day ON daily_usage(day);');
      db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_start ON sessions(start_ms);');
      // v1 -> v2：分类自定义图片
      if (v < 2) {
        db.execute('ALTER TABLE categories ADD COLUMN icon_path TEXT;');
      }
      db.execute('PRAGMA user_version=$_dbVersion;');
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    }
  }

  static String _ensureDeviceId(Database db) {
    final rows = db.select("SELECT v FROM settings WHERE k='device_id'");
    if (rows.isNotEmpty) return rows.first['v'] as String;
    final id = _newDeviceId();
    db.prepare("INSERT INTO settings(k,v) VALUES('device_id',?)").execute([id]);
    return id;
  }

  static String _newDeviceId() {
    final rand = DateTime.now().microsecondsSinceEpoch;
    final r = rand.toRadixString(16);
    return 'dev-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}-$r';
  }

  // ---------- settings ----------
  String? getSetting(String k) {
    final r = db.select('SELECT v FROM settings WHERE k=?', [k]);
    return r.isEmpty ? null : r.first['v'] as String?;
  }

  void setSetting(String k, String? v) {
    db.prepare(
      'INSERT INTO settings(k,v) VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v',
    ).execute([k, v]);
  }

  // ---------- apps ----------
  AppEntry? findApp(String package, String platform) {
    final r = db.select(
      'SELECT * FROM apps WHERE package=? AND platform=?',
      [package, platform],
    );
    return r.isEmpty ? null : AppEntry.fromRow(r.first);
  }

  AppEntry appById(int id) =>
      AppEntry.fromRow(db.select('SELECT * FROM apps WHERE id=?', [id]).first);

  int insertApp(AppEntry a) {
    db.prepare('''
INSERT INTO apps(package,platform,name,install_date_ms,first_seen_ms,last_seen_ms,
  is_system,uninstalled,reinstall_count,description,rating,daily_limit_minutes,icon_path)
VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)''').execute([
      a.package, a.platform, a.name, a.installDateMs, a.firstSeenMs, a.lastSeenMs,
      a.isSystem, a.uninstalled, a.reinstallCount, a.description, a.rating,
      a.dailyLimitMinutes, a.iconPath,
    ]);
    return db.lastInsertRowId;
  }

  void updateApp(AppEntry a) {
    db.prepare('''
UPDATE apps SET name=?, install_date_ms=?, last_seen_ms=?, is_system=?,
  uninstalled=?, reinstall_count=?, description=?, rating=?,
  daily_limit_minutes=?, icon_path=? WHERE id=?''').execute([
      a.name, a.installDateMs, a.lastSeenMs, a.isSystem, a.uninstalled,
      a.reinstallCount, a.description, a.rating, a.dailyLimitMinutes,
      a.iconPath, a.id,
    ]);
  }

  /// 同步字典用：仅更新轻量字段（名称/安装日期/在装状态），绝不覆盖本地编辑。
  void upsertAppDictionary(String package, String platform, String? name,
      int? installDateMs, int seenMs, int uninstalled, int reinstall) {
    final existing = findApp(package, platform);
    if (existing == null) {
      insertApp(AppEntry(
        id: 0,
        package: package,
        platform: platform,
        name: name ?? package,
        installDateMs: installDateMs,
        firstSeenMs: seenMs,
        lastSeenMs: seenMs,
        uninstalled: uninstalled,
        reinstallCount: reinstall,
      ));
    } else {
      db.prepare(
          'UPDATE apps SET name=?, install_date_ms=COALESCE(install_date_ms,?), last_seen_ms=MAX(last_seen_ms,?), uninstalled=?, reinstall_count=MAX(reinstall_count,?) WHERE id=?')
          .execute([name ?? existing.name, installDateMs, seenMs, uninstalled, reinstall, existing.id]);
    }
  }

  List<AppEntry> allApps({String? platform}) {
    final r = platform == null
        ? db.select('SELECT * FROM apps ORDER BY name COLLATE NOCASE')
        : db.select('SELECT * FROM apps WHERE platform=? ORDER BY name COLLATE NOCASE',
            [platform]);
    return r.map(AppEntry.fromRow).toList();
  }

  // ---------- categories ----------
  List<Category> allCategories() {
    return db
        .select('SELECT * FROM categories ORDER BY sort_order, id')
        .map(Category.fromRow)
        .toList();
  }

  int insertCategory(String name, int color, int icon, int sortOrder, {String? iconPath}) {
    db.prepare(
            'INSERT INTO categories(name,color,icon,icon_path,sort_order) VALUES(?,?,?,?,?)')
        .execute([name, color, icon, iconPath, sortOrder]);
    return db.lastInsertRowId;
  }

  void updateCategory(Category c) => db
      .prepare(
          'UPDATE categories SET name=?,color=?,icon=?,icon_path=?,sort_order=? WHERE id=?')
      .execute([c.name, c.colorValue, c.iconCodePoint, c.iconPath, c.sortOrder, c.id]);

  void deleteCategory(int id) =>
      db.prepare('DELETE FROM categories WHERE id=?').execute([id]);

  void setAppCategories(int appId, List<int> categoryIds) {
    db.execute('BEGIN');
    try {
      db.prepare('DELETE FROM app_categories WHERE app_id=?').execute([appId]);
      final stmt = db
          .prepare('INSERT OR IGNORE INTO app_categories(app_id,category_id) VALUES(?,?)');
      for (final c in categoryIds) {
        stmt.execute([appId, c]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void toggleAppCategory(int appId, int categoryId, bool on) {
    if (on) {
      db.prepare('INSERT OR IGNORE INTO app_categories(app_id,category_id) VALUES(?,?)')
        ..execute([appId, categoryId])
        ..dispose();
    } else {
      db.prepare('DELETE FROM app_categories WHERE app_id=? AND category_id=?')
        ..execute([appId, categoryId])
        ..dispose();
    }
  }

  List<int> categoryIdsOfApp(int appId) => db
      .select('SELECT category_id FROM app_categories WHERE app_id=?', [appId])
      .map((r) => r['category_id'] as int)
      .toList();

  /// 全部应用→分类映射（一次查询，避免循环里逐应用 SELECT）。
  Map<int, List<int>> appCategoryMap() {
    final r = db.select('SELECT app_id, category_id FROM app_categories');
    final map = <int, List<int>>{};
    for (final row in r) {
      map.putIfAbsent(row['app_id'] as int, () => []).add(row['category_id'] as int);
    }
    return map;
  }

  List<AppEntry> appsOfCategory(int categoryId, {String? platform}) {
    final rows = db.select('''
SELECT a.* FROM apps a JOIN app_categories ac ON ac.app_id=a.id
WHERE ac.category_id=? ${platform == null ? '' : 'AND a.platform=?'}
ORDER BY a.name COLLATE NOCASE''',
        platform == null ? [categoryId] : [categoryId, platform]);
    return rows.map(AppEntry.fromRow).toList();
  }

  /// 未分类 = 没有任何标签的应用
  List<AppEntry> uncategorizedApps({String? platform}) {
    final rows = db.select('''
SELECT * FROM apps a WHERE NOT EXISTS(SELECT 1 FROM app_categories ac WHERE ac.app_id=a.id)
${platform == null ? '' : 'AND a.platform=?'}
ORDER BY a.name COLLATE NOCASE''',
        platform == null ? const [] : [platform]);
    return rows.map(AppEntry.fromRow).toList();
  }

  // ---------- sources ----------
  List<AppSource> sourcesOfApp(int appId) => db
      .select('SELECT * FROM app_sources WHERE app_id=? ORDER BY sort_order,id', [appId])
      .map(AppSource.fromRow)
      .toList();

  int addSource(int appId, String label, String? url) {
    final n = db.select('SELECT COUNT(*) c FROM app_sources WHERE app_id=?', [appId])
        .first['c'] as int;
    db.prepare('INSERT INTO app_sources(app_id,label,url,sort_order) VALUES(?,?,?,?)')
        .execute([appId, label, url, n]);
    return db.lastInsertRowId;
  }

  void updateSource(AppSource s) => db
      .prepare('UPDATE app_sources SET label=?,url=? WHERE id=?')
      .execute([s.label, s.url, s.id]);

  void deleteSource(int id) =>
      db.prepare('DELETE FROM app_sources WHERE id=?').execute([id]);

  // ---------- daily usage ----------
  /// 合并一条日统计：同键取较大值（系统 UsageStats 是权威总量，防止回退）。
  /// 返回是否发生变化。
  bool mergeDaily(int appId, String deviceId, String day, int timeMs, int updatedMs) {
    final r = db.select(
      'SELECT time_ms FROM daily_usage WHERE app_id=? AND device_id=? AND day=?',
      [appId, deviceId, day],
    );
    if (r.isEmpty) {
      if (timeMs <= 0) return false;
      db.prepare(
          'INSERT INTO daily_usage(app_id,device_id,day,time_ms,updated_ms) VALUES(?,?,?,?,?)')
        ..execute([appId, deviceId, day, timeMs, updatedMs])
        ..dispose();
      return true;
    }
    final old = r.first['time_ms'] as int;
    if (timeMs > old) {
      db.prepare(
          'UPDATE daily_usage SET time_ms=?,updated_ms=? WHERE app_id=? AND device_id=? AND day=?')
        ..execute([timeMs, updatedMs, appId, deviceId, day])
        ..dispose();
      return true;
    }
    return false;
  }

  /// 某应用在 [startKey,endKey] 每天的总时长（跨设备求和）。
  Map<String, int> dailyTotals(int appId, String startKey, String endKey) {
    final r = db.select('''
SELECT day, SUM(time_ms) t FROM daily_usage
WHERE app_id=? AND day>=? AND day<=? GROUP BY day''', [appId, startKey, endKey]);
    return {for (final row in r) row['day'] as String: row['t'] as int};
  }

  /// 某一天各应用总时长（跨设备）。
  List<Map<String, Object?>> totalsPerAppBetween(String startKey, String endKey,
      {String? platform}) {
    return db.select('''
SELECT a.id id, a.package package, a.name name, a.platform platform,
       a.uninstalled uninstalled, a.icon_path icon_path, SUM(u.time_ms) t
FROM daily_usage u JOIN apps a ON a.id=u.app_id
WHERE u.day>=? AND u.day<=?
${platform == null ? '' : 'AND a.platform=?'}
GROUP BY a.id ORDER BY t DESC''',
        platform == null ? [startKey, endKey] : [startKey, endKey, platform]);
  }

  int totalOfApp(int appId) {
    final r =
        db.select('SELECT COALESCE(SUM(time_ms),0) t FROM daily_usage WHERE app_id=?', [appId]);
    return r.first['t'] as int;
  }

  String? firstUsageDay(int appId) {
    final r = db.select(
        'SELECT MIN(day) d FROM daily_usage WHERE app_id=? AND time_ms>0', [appId]);
    return r.first['d'] as String?;
  }

  /// 全部日统计（同步/备份用）
  List<DailyUsage> allDaily() =>
      db.select('SELECT * FROM daily_usage').map(DailyUsage.fromRow).toList();

  // ---------- sessions ----------
  void insertSession(UsageSession s) {
    db.prepare(
        'INSERT INTO sessions(app_id,device_id,start_ms,end_ms) VALUES(?,?,?,?)')
      ..execute([s.appId, s.deviceId, s.startMs, s.endMs])
      ..dispose();
  }

  void insertSessionsBatch(List<UsageSession> list) {
    if (list.isEmpty) return;
    final stmt = db
        .prepare('INSERT INTO sessions(app_id,device_id,start_ms,end_ms) VALUES(?,?,?,?)');
    db.execute('BEGIN');
    try {
      for (final s in list) {
        stmt.execute([s.appId, s.deviceId, s.startMs, s.endMs]);
      }
      stmt.dispose();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// 某应用在区间内的片段（按开始时间）
  List<UsageSession> sessionsBetween(int appId, int startMs, int endMs) => db
      .select(
          'SELECT * FROM sessions WHERE app_id=? AND start_ms>=? AND start_ms<? ORDER BY start_ms',
          [appId, startMs, endMs])
      .map((r) => UsageSession(
          id: r['id'] as int,
          appId: r['app_id'] as int,
          deviceId: r['device_id'] as String,
          startMs: r['start_ms'] as int,
          endMs: r['end_ms'] as int))
      .toList();

  /// 清理 31 天前的片段
  void pruneSessions(int beforeMs) =>
      db.prepare('DELETE FROM sessions WHERE start_ms<?').execute([beforeMs]);

  /// 删除指定时间区间内的片段（重新采集前清理，避免重复）
  void deleteSessionsBetween(int startMs, int endMs) =>
      db.prepare('DELETE FROM sessions WHERE start_ms>=? AND start_ms<?')
          .execute([startMs, endMs]);

  // ---------- maintenance ----------
  void close() => db.dispose();
}
