import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../data/db.dart';
import '../data/models.dart';
import 'webdav.dart';

String appKeyOf(String package, String platform) => '$platform:$package';

class SyncReport {
  final int remoteDevices;
  final int remoteDays;
  final int uploadedDays;
  final String? error;
  const SyncReport(
      {this.remoteDevices = 0, this.remoteDays = 0, this.uploadedDays = 0, this.error});
  bool get ok => error == null;
}

/// WebDAV 手动同步 + 本地全量备份/恢复。
class DataService {
  final AppDatabase db;
  DataService(this.db);

  String get _device => db.deviceId;

  // ================= WebDAV 同步（仅统计数据 + 应用字典，增量合并不覆盖） =================

  Future<SyncReport> syncViaWebDav({
    required String url,
    required String username,
    required String password,
    required String deviceName,
    required String platform,
    String root = 'screentime',
  }) async {
    try {
      final client = WebDavClient(baseUrl: url, username: username, password: password);
      await client.ping();
      final dir = '$root/devices';
      await client.ensureDir(dir);

      // 1) 拉取其他设备文件并合并
      final files = await client.listFiles(dir);
      var remoteDevices = 0;
      var remoteDays = 0;
      for (final f in files) {
        if (!f.endsWith('.json')) continue;
        final text = await client.getText('$dir/$f');
        if (text == null || text.isEmpty) continue;
        Map<String, dynamic> j;
        try {
          j = jsonDecode(text) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        if (j['device_id'] == _device) continue; // 自己的文件不回并
        remoteDevices++;
        remoteDays += _mergeRemoteSnapshot(j);
      }

      // 2) 生成本机快照（仅本设备的日统计）并上传
      final snap = _buildLocalSnapshot(deviceName, platform);
      await client.putText('$dir/$_device.json', jsonEncode(snap));
      db.setSetting('last_sync_ms', DateTime.now().millisecondsSinceEpoch.toString());
      return SyncReport(
          remoteDevices: remoteDevices,
          remoteDays: remoteDays,
          uploadedDays: (snap['daily'] as List).length);
    } catch (e) {
      return SyncReport(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Map<String, dynamic> _buildLocalSnapshot(String deviceName, String platform) {
    final apps = db.allApps();
    final appList = apps
        .map((a) => {
              'key': appKeyOf(a.package, a.platform),
              'package': a.package,
              'platform': a.platform,
              'name': a.name,
              'install_date_ms': a.installDateMs,
              'uninstalled': a.uninstalled,
              'reinstall_count': a.reinstallCount,
            })
        .toList();
    final rows = db.db.select(
      'SELECT u.time_ms t,u.day d,a.package p,a.platform pl FROM daily_usage u '
      'JOIN apps a ON a.id=u.app_id WHERE u.device_id=?',
      [_device],
    );
    final daily = rows
        .map((r) => {
              'key': appKeyOf(r['p'] as String, r['pl'] as String),
              'day': r['d'] as String,
              'time_ms': r['t'] as int,
            })
        .toList();
    return {
      'format': 'screen_time_journal_sync_v1',
      'device_id': _device,
      'device_name': deviceName,
      'platform': platform,
      'updated_ms': DateTime.now().millisecondsSinceEpoch,
      'apps': appList,
      'daily': daily,
    };
  }

  /// 合并一份远端设备快照，返回写入/更新的日记录数
  int _mergeRemoteSnapshot(Map<String, dynamic> j) {
    final remoteDevice = j['device_id'] as String?;
    if (remoteDevice == null) return 0;
    final updated = (j['apps'] as List?) ?? const [];
    for (final a in updated) {
      final m = a as Map<String, dynamic>;
      final pkg = m['package'] as String?;
      final pl = m['platform'] as String?;
      if (pkg == null || pl == null) continue;
      db.upsertAppDictionary(
        pkg,
        pl,
        m['name'] as String?,
        m['install_date_ms'] as int?,
        (m['updated_ms'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        (m['uninstalled'] as int?) ?? 0,
        (m['reinstall_count'] as int?) ?? 0,
      );
    }
    var n = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in (j['daily'] as List?) ?? const []) {
      final m = d as Map<String, dynamic>;
      final key = m['key'] as String?;
      final day = m['day'] as String?;
      final t = (m['time_ms'] as num?)?.toInt();
      if (key == null || day == null || t == null) continue;
      final parts = key.split(':');
      if (parts.length < 2) continue;
      final pl = parts.first;
      final pkg = parts.sublist(1).join(':');
      var app = db.findApp(pkg, pl);
      if (app == null) {
        final id = db.insertApp(AppEntry(
          id: 0,
          package: pkg,
          platform: pl,
          name: pkg,
          firstSeenMs: now,
          lastSeenMs: now,
          uninstalled: 1,
        ));
        app = db.appById(id);
      }
      if (db.mergeDaily(app.id, remoteDevice, day, t, now)) n++;
    }
    return n;
  }

  // ================= 手动全量备份（含分类/评分/描述/来源/限额） =================

  Map<String, dynamic> buildBackup(String deviceName) {
    final apps = db.allApps();
    final cats = db.allCategories();
    final catNameById = {for (final c in cats) c.id: c.name};
    final appKeyById = <int, String>{};
    final appList = <Map<String, dynamic>>[];
    for (final a in apps) {
      appKeyById[a.id] = appKeyOf(a.package, a.platform);
      appList.add({
        'package': a.package,
        'platform': a.platform,
        'name': a.name,
        'install_date_ms': a.installDateMs,
        'first_seen_ms': a.firstSeenMs,
        'is_system': a.isSystem,
        'uninstalled': a.uninstalled,
        'reinstall_count': a.reinstallCount,
        'description': a.description,
        'rating': a.rating,
        'daily_limit_minutes': a.dailyLimitMinutes,
        'sources': db.sourcesOfApp(a.id).map((s) => {'label': s.label, 'url': s.url}).toList(),
        'categories': db
            .categoryIdsOfApp(a.id)
            .map((cid) => catNameById[cid])
            .whereType<String>()
            .toList(),
      });
    }
    final dailyRows = db.db.select('''
SELECT a.package p,a.platform pl,u.device_id dev,u.day d,u.time_ms t
FROM daily_usage u JOIN apps a ON a.id=u.app_id''');
    return {
      'format': 'screen_time_journal_backup_v1',
      'exported_ms': DateTime.now().millisecondsSinceEpoch,
      'device_id': _device,
      'device_name': deviceName,
      'categories': cats
          .map((c) => {'name': c.name, 'color': c.colorValue, 'icon': c.iconCodePoint})
          .toList(),
      'apps': appList,
      'daily_usage': dailyRows
          .map((r) => {
                'key': appKeyOf(r['p'] as String, r['pl'] as String),
                'device_id': r['dev'] as String,
                'day': r['d'] as String,
                'time_ms': r['t'] as int,
              })
          .toList(),
    };
  }

  Future<String?> exportToFile(String deviceName) async {
    final data = jsonEncode(buildBackup(deviceName));
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .substring(0, 15)
        .replaceAll('T', '_');
    final bytes = Uint8List.fromList(utf8.encode(data));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出屏记完整备份',
      fileName: 'pingji_backup_$stamp.json',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return null;
    // 部分平台 saveFile 已直接写入 bytes；若返回路径但未写入则补写
    try {
      final f = await _maybeWrite(path, bytes);
      return f;
    } catch (_) {
      return path;
    }
  }

  Future<String> _maybeWrite(String path, Uint8List bytes) async {
    // file_picker 在桌面端返回路径且不会自动落盘，需要手动写
    final f = await File(path).writeAsBytes(bytes, flush: true);
    return f.path;
  }

  Future<Map<String, int>?> importFromFile({bool overwrite = false}) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return null;
    final text = utf8.decode(res.files.first.bytes!, allowMalformed: false);
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['format'] != 'screen_time_journal_backup_v1') {
      throw const FormatException('不是有效的屏记备份文件');
    }
    return restoreBackup(j, overwrite: overwrite);
  }

  /// 恢复备份。overwrite=true 会清空现有数据（危险）；否则增量合并、不覆盖本地编辑。
  Map<String, int> restoreBackup(Map<String, dynamic> j, {required bool overwrite}) {
    if (overwrite) {
      db.db.execute('DELETE FROM daily_usage;');
      db.db.execute('DELETE FROM app_categories;');
      db.db.execute('DELETE FROM app_sources;');
      db.db.execute('DELETE FROM categories;');
      db.db.execute('DELETE FROM apps;');
    }
    final now = DateTime.now().millisecondsSinceEpoch;

    // 分类（按名去重）
    final catNameId = <String, int>{for (final c in db.allCategories()) c.name: c.id};
    for (final c in (j['categories'] as List?) ?? const []) {
      final m = c as Map<String, dynamic>;
      final name = m['name'] as String?;
      if (name == null) continue;
      if (catNameId[name] != null) continue;
      final order = catNameId.length;
      final id = db.insertCategory(
          name, (m['color'] as int?) ?? 0xFF78909C, (m['icon'] as int?) ?? 0xe148, order);
      catNameId[name] = id;
    }

    var appCount = 0;
    var dailyCount = 0;
    for (final a in (j['apps'] as List?) ?? const []) {
      final m = a as Map<String, dynamic>;
      final pkg = m['package'] as String?;
      final pl = m['platform'] as String?;
      if (pkg == null || pl == null) continue;
      var app = db.findApp(pkg, pl);
      final catNames = (m['categories'] as List?)?.cast<String>() ?? const [];
      final sources = (m['sources'] as List?) ?? const [];
      if (app == null) {
        final id = db.insertApp(AppEntry(
          id: 0,
          package: pkg,
          platform: pl,
          name: m['name'] as String? ?? pkg,
          installDateMs: m['install_date_ms'] as int?,
          firstSeenMs: (m['first_seen_ms'] as int?) ?? now,
          lastSeenMs: now,
          isSystem: (m['is_system'] as int?) ?? 0,
          uninstalled: (m['uninstalled'] as int?) ?? 0,
          reinstallCount: (m['reinstall_count'] as int?) ?? 0,
          description: m['description'] as String?,
          rating: (m['rating'] as num?)?.toDouble(),
          dailyLimitMinutes: m['daily_limit_minutes'] as int?,
        ));
        app = db.appById(id);
        appCount++;
      } else if (overwrite) {
        db.updateApp(app.copyWith(
          name: m['name'] as String?,
          installDateMs: m['install_date_ms'] as int?,
          uninstalled: m['uninstalled'] as int?,
          description: m['description'] as String?,
          rating: (m['rating'] as num?)?.toDouble(),
          dailyLimitMinutes: m['daily_limit_minutes'] as int?,
          clearDescription: m['description'] == null,
          clearRating: m['rating'] == null,
          clearLimit: m['daily_limit_minutes'] == null,
        ));
        app = db.appById(app.id);
        db.db.execute('DELETE FROM app_categories WHERE app_id=?', [app.id]);
        db.db.execute('DELETE FROM app_sources WHERE app_id=?', [app.id]);
      } else {
        // 合并：仅补全本地为空的编辑字段
        db.updateApp(app.copyWith(
          installDateMs: app.installDateMs == null ? m['install_date_ms'] as int? : null,
          description: app.description == null ? m['description'] as String? : null,
          rating: app.rating == null ? (m['rating'] as num?)?.toDouble() : null,
          dailyLimitMinutes:
              app.dailyLimitMinutes == null ? m['daily_limit_minutes'] as int? : null,
          clearDescription: app.description == null && m['description'] == null,
          clearRating: app.rating == null && m['rating'] == null,
          clearLimit: app.dailyLimitMinutes == null && m['daily_limit_minutes'] == null,
        ));
        app = db.appById(app.id);
      }

      // 分类标签
      final existingCats = db.categoryIdsOfApp(app.id).toSet();
      for (final name in catNames) {
        final cid = catNameId[name];
        if (cid != null && !existingCats.contains(cid)) {
          db.toggleAppCategory(app.id, cid, true);
        }
      }
      // 来源（覆盖模式已清空；合并模式去重 by url/label）
      if (overwrite || db.sourcesOfApp(app.id).isEmpty) {
        for (final s in sources) {
          final sm = s as Map<String, dynamic>;
          final label = sm['label'] as String?;
          if (label == null) continue;
          db.addSource(app.id, label, sm['url'] as String?);
        }
      }
    }

    // 日统计：max 合并不回退
    final devId = (j['device_id'] as String?) ?? _device;
    for (final d in (j['daily_usage'] as List?) ?? const []) {
      final m = d as Map<String, dynamic>;
      final key = m['key'] as String?;
      final day = m['day'] as String?;
      final t = (m['time_ms'] as num?)?.toInt();
      if (key == null || day == null || t == null) continue;
      final parts = key.split(':');
      if (parts.length < 2) continue;
      final pl = parts.first;
      final pkg = parts.sublist(1).join(':');
      var app = db.findApp(pkg, pl);
      if (app == null) {
        final id = db.insertApp(AppEntry(
            id: 0,
            package: pkg,
            platform: pl,
            name: pkg,
            firstSeenMs: now,
            lastSeenMs: now));
        app = db.appById(id);
      }
      if (db.mergeDaily(app.id, m['device_id'] as String? ?? devId, day, t, now)) {
        dailyCount++;
      }
    }
    return {'apps': appCount, 'daily': dailyCount, 'categories': catNameId.length};
  }
}
