/// 应用注册表中的一个应用（卸载不删除记录）。
class AppEntry {
  /// 数据库自增 id；尚未入库的新对象用 0 占位。
  final int id;
  final String package; // Android 包名 / Windows exe 完整路径（全局唯一标识）
  final String platform; // 'android' | 'windows'
  final String name;
  final int? installDateMs; // 安装日期（可编辑）
  final int firstSeenMs; // 本应用首次发现时间
  final int lastSeenMs;
  final int isSystem;
  final int uninstalled; // 1=当前未安装（历史数据保留）
  final int reinstallCount;
  final String? description;
  final double? rating; // 1~10
  final int? dailyLimitMinutes; // 单日限额（分钟），null=不限
  final String? iconPath; // 本地缓存图标文件路径

  const AppEntry({
    required this.id,
    required this.package,
    required this.platform,
    required this.name,
    this.installDateMs,
    required this.firstSeenMs,
    required this.lastSeenMs,
    this.isSystem = 0,
    this.uninstalled = 0,
    this.reinstallCount = 0,
    this.description,
    this.rating,
    this.dailyLimitMinutes,
    this.iconPath,
  });

  DateTime? get installDate =>
      installDateMs == null ? null : DateTime.fromMillisecondsSinceEpoch(installDateMs!);

  AppEntry copyWith({
    String? name,
    int? installDateMs,
    int? lastSeenMs,
    int? isSystem,
    int? uninstalled,
    int? reinstallCount,
    String? description,
    double? rating,
    int? dailyLimitMinutes,
    String? iconPath,
    bool clearInstallDate = false,
    bool clearDescription = false,
    bool clearRating = false,
    bool clearLimit = false,
    bool clearIcon = false,
  }) {
    return AppEntry(
      id: id,
      package: package,
      platform: platform,
      name: name ?? this.name,
      installDateMs: clearInstallDate ? null : (installDateMs ?? this.installDateMs),
      firstSeenMs: firstSeenMs,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      isSystem: isSystem ?? this.isSystem,
      uninstalled: uninstalled ?? this.uninstalled,
      reinstallCount: reinstallCount ?? this.reinstallCount,
      description: clearDescription ? null : (description ?? this.description),
      rating: clearRating ? null : (rating ?? this.rating),
      dailyLimitMinutes:
          clearLimit ? null : (dailyLimitMinutes ?? this.dailyLimitMinutes),
      iconPath: clearIcon ? null : (iconPath ?? this.iconPath),
    );
  }

  factory AppEntry.fromRow(Map<String, Object?> r) => AppEntry(
        id: r['id'] as int,
        package: r['package'] as String,
        platform: r['platform'] as String,
        name: r['name'] as String,
        installDateMs: r['install_date_ms'] as int?,
        firstSeenMs: r['first_seen_ms'] as int,
        lastSeenMs: r['last_seen_ms'] as int,
        isSystem: (r['is_system'] as int?) ?? 0,
        uninstalled: (r['uninstalled'] as int?) ?? 0,
        reinstallCount: (r['reinstall_count'] as int?) ?? 0,
        description: r['description'] as String?,
        rating: (r['rating'] as num?)?.toDouble(),
        dailyLimitMinutes: r['daily_limit_minutes'] as int?,
        iconPath: r['icon_path'] as String?,
      );
}

class Category {
  final int id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final String? iconPath; // 自定义图片（文件路径），优先于 iconCodePoint
  final int sortOrder;

  const Category({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    this.iconPath,
    required this.sortOrder,
  });

  Category copyWith(
          {String? name, int? colorValue, int? iconCodePoint, String? iconPath, int? sortOrder}) =>
      Category(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        iconPath: iconPath ?? this.iconPath,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  factory Category.fromRow(Map<String, Object?> r) => Category(
        id: r['id'] as int,
        name: r['name'] as String,
        colorValue: r['color'] as int,
        iconCodePoint: r['icon'] as int,
        iconPath: r['icon_path'] as String?,
        sortOrder: (r['sort_order'] as int?) ?? 0,
      );
}

class AppSource {
  final int id;
  final int appId;
  final String label;
  final String? url; // null=纯文字备注

  const AppSource({required this.id, required this.appId, required this.label, this.url});

  factory AppSource.fromRow(Map<String, Object?> r) => AppSource(
        id: r['id'] as int,
        appId: r['app_id'] as int,
        label: r['label'] as String,
        url: r['url'] as String?,
      );
}

/// 按 (应用, 设备, 天) 聚合的使用时长 —— 统计与同步的最小单元。
class DailyUsage {
  final int appId;
  final String deviceId;
  final String day; // yyyy-MM-dd
  final int timeMs;
  final int updatedMs;

  const DailyUsage({
    required this.appId,
    required this.deviceId,
    required this.day,
    required this.timeMs,
    required this.updatedMs,
  });

  factory DailyUsage.fromRow(Map<String, Object?> r) => DailyUsage(
        appId: r['app_id'] as int,
        deviceId: r['device_id'] as String,
        day: r['day'] as String,
        timeMs: r['time_ms'] as int,
        updatedMs: r['updated_ms'] as int,
      );
}

/// 一次前台使用片段（用于 24 小时时间轴、限额判断；仅本机保留近 31 天）。
class UsageSession {
  final int? id;
  final int appId;
  final String deviceId;
  final int startMs;
  final int endMs;

  const UsageSession({
    this.id,
    required this.appId,
    required this.deviceId,
    required this.startMs,
    required this.endMs,
  });

  int get durationMs => endMs - startMs;
}
