import 'package:flutter/material.dart';
import '../../../core/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../state/app_state.dart';
import 'about_page.dart';
import 'backup_page.dart';
import 'webdav_page.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  /// 可选主题色调（Material 3 seed，整套界面配色随之变化）
  static const _accentSeeds = <int>[
    0xFF1F9E89, // 青绿（默认）
    0xFF2D6CDF, // 蓝
    0xFF3949AB, // 靛蓝
    0xFF7C4DFF, // 紫
    0xFFE91E63, // 粉
    0xFFD32F2F, // 红
    0xFFF57C00, // 橙
    0xFFF2A900, // 琥珀
    0xFF43A047, // 绿
    0xFF00ACC1, // 青
    0xFF8D6E63, // 棕
    0xFF607D8B, // 蓝灰
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final n = s.native;
    final lastSync = s.lastSyncMs;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('设置'), style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _header(context, AppStrings.t('数据与同步')),
          _tile(context, Icons.cloud_sync_outlined, AppStrings.t('WebDAV 同步'),
              subtitle: AppStrings.t('手动点击同步，多设备统计增量合并不覆盖'),
              trailing: lastSync == null
                  ? Text(AppStrings.t('未同步'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)))
                  : Text('${AppStrings.t('上次')}${Fmt.date(DateTime.fromMillisecondsSinceEpoch(int.parse(lastSync)))}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
              page: WebDavPage()),
          _tile(context, Icons.save_outlined, AppStrings.t('备份与恢复'),
              subtitle: AppStrings.t('手动导出 / 导入完整备份（含分类、评分、描述、来源、限额）'),
              page: BackupPage()),
          if (n.isAndroid && !s.historyImported)
            _tile(
              context,
              Icons.history,
              AppStrings.t('导入系统历史记录'),
              subtitle: AppStrings.t('读取手机已有的应用使用时间（仅首次可用）'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(content: Text(AppStrings.t('正在读取系统历史记录…'))),
                );
                final r = await s.importHistory();
                messenger.showSnackBar(SnackBar(
                    content: Text(r.error != null
                        ? '${AppStrings.t('导入失败：')}${r.error}'
                        : AppStrings.importDone(r.daysChanged))));
              },
            ),
          SizedBox(height: 18),
          _header(context, AppStrings.t('外观')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.t('主题模式'),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system,
                        label: Text(AppStrings.t('跟随系统')),
                        icon: Icon(Icons.brightness_auto, size: 16)),
                    ButtonSegment(value: ThemeMode.light,
                        label: Text(AppStrings.t('浅色')),
                        icon: Icon(Icons.light_mode_outlined, size: 16)),
                    ButtonSegment(value: ThemeMode.dark,
                        label: Text(AppStrings.t('深色')),
                        icon: Icon(Icons.dark_mode_outlined, size: 16)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.t('主题色调'),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final c in _accentSeeds)
                      GestureDetector(
                        onTap: () => s.setThemeSeed(c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: s.themeSeed == c
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: s.themeSeed == c
                              ? Icon(Icons.check,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onPrimary)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(AppStrings.t('语言'),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'system',
                        label: Text(AppStrings.t('跟随系统')),
                        icon: Icon(Icons.language, size: 16)),
                    const ButtonSegment(value: 'zh', label: Text('中文')),
                    const ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {s.appLanguage},
                  onSelectionChanged: (v) => s.setAppLanguage(v.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          _header(context, AppStrings.t('运行与权限')),
          if (n.isAndroid)
            _Switch(
              icon: Icons.shield_outlined,
              title: AppStrings.t('后台监控服务'),
              subtitle: AppStrings.t('用于限额实时提醒；关闭后统计仍会在打开 App 时回填'),
              value: s.monitorEnabled,
              onChanged: (v) => s.setMonitorEnabled(v),
            ),
          if (n.isAndroid)
            _tile(context, Icons.verified_user_outlined, AppStrings.t('权限管理'),
                subtitle: AppStrings.t('使用情况、电池白名单、悬浮窗、无障碍、通知、自启动'),
                page: PermissionsPage()),
          if (n.isWindows) _WindowsAutoStart(),
          SizedBox(height: 18),
          _header(context, AppStrings.t('本机')),
          _DeviceNameTile(),
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(AppStrings.deviceId(s.deviceId),
                style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
          ),
          SizedBox(height: 18),
          _header(context, AppStrings.t('关于')),
          _tile(context, Icons.info_outline, AppStrings.t('关于屏记'),
              subtitle: '${AppStrings.t('版本')} ${AppState.appVersion}',
              page: const AboutPage()),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Text(t,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
      );

  Widget _tile(BuildContext context, IconData icon, String title,
      {String? subtitle, Widget? trailing, Widget? page, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        child: ListTile(
          leading: Icon(icon, size: 21),
          title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, style: TextStyle(fontSize: 11.5), maxLines: 2),
          trailing: trailing ?? (page != null ? Icon(Icons.chevron_right) : null),
          onTap: onTap ??
              (page == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page))),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch(
      {required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        child: SwitchListTile(
          secondary: Icon(icon, size: 21),
          title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5)),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _WindowsAutoStart extends StatefulWidget {
  @override
  State<_WindowsAutoStart> createState() => _WindowsAutoStartState();
}

class _WindowsAutoStartState extends State<_WindowsAutoStart> {
  bool? _v;
  @override
  void initState() {
    super.initState();
    context.read<AppState>().readWindowsAutoStart().then((v) => setState(() => _v = v));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        child: SwitchListTile(
          secondary: Icon(Icons.power_settings_new, size: 21),
          title: Text(AppStrings.t('开机自动启动'),
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: Text(AppStrings.t('登录 Windows 后自动在后台记录前台软件'),
              style: TextStyle(fontSize: 11.5)),
          value: _v ?? false,
          onChanged: (v) async {
            await context.read<AppState>().setWindowsAutoStart(v);
            setState(() => _v = v);
          },
        ),
      ),
    );
  }
}

class _DeviceNameTile extends StatefulWidget {
  @override
  State<_DeviceNameTile> createState() => _DeviceNameTileState();
}

class _DeviceNameTileState extends State<_DeviceNameTile> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(15),
      child: ListTile(
        leading: Icon(Icons.devices, size: 21),
        title: Text(AppStrings.t('本机名称'),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Text(s.deviceName, style: TextStyle(fontSize: 12)),
        trailing: Icon(Icons.edit, size: 18),
        onTap: () async {
          final ctl = TextEditingController(text: s.deviceName);
          final name = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(AppStrings.t('设备名称')),
              content: TextField(
                controller: ctl,
                decoration: InputDecoration(hintText: AppStrings.t('例如：我的手机 / 公司电脑')),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('取消'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, ctl.text), child: Text(AppStrings.t('保存'))),
              ],
            ),
          );
          if (name != null && name.trim().isNotEmpty) {
            s.saveWebDavConfig(name: name);
          }
        },
      ),
    );
  }
}

// ---------------- 权限管理 ----------------

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = context.read<AppState>().native;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('权限管理'))),
      body: FutureBuilder(
        future: Future.wait([
          n.hasUsagePermission(),
          n.isIgnoringBattery(),
          n.canDrawOverlays(),
          n.isAccessibilityEnabled(),
          n.notificationsEnabled(),
        ]),
        builder: (_, snap) {
          final v = snap.data;
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              _perm(AppStrings.t('使用情况访问权限'), AppStrings.t('读取应用使用时长的核心权限'), v?[0],
                  () => n.requestUsagePermission()),
              _perm(AppStrings.t('电池优化白名单'), AppStrings.t('防止后台统计被系统杀死'), v?[1],
                  () => n.requestIgnoreBattery()),
              _perm(AppStrings.t('悬浮窗'), AppStrings.t('达到限额时全屏遮挡提醒'), v?[2],
                  () => n.requestOverlayPermission()),
              _perm(AppStrings.t('无障碍服务'), AppStrings.t('达到限额时自动回到桌面'), v?[3],
                  () => n.openAccessibilitySettings()),
              _perm(AppStrings.t('通知'), AppStrings.t('显示后台统计常驻通知'), v?[4],
                  () => n.openNotificationSettings()),
              _perm(AppStrings.t('自启动（厂商设置）'), AppStrings.t('小米/OPPO/vivo/华为等建议允许'), null,
                  () => n.openAutoStartSettings(),
                  actionLabel: AppStrings.t('打开设置')),
              SizedBox(height: 12),
              Text(
                AppStrings.t('提示：受 Android 限制，普通应用无法强制关闭其他应用；限额功能通过')
                + AppStrings.t('“全屏遮挡 + 回到桌面”实现，需要悬浮窗与无障碍权限。'),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45), height: 1.6),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _perm(String title, String subtitle, bool? ok, VoidCallback onTap,
      {String? actionLabel}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5)),
          trailing: ok == null
              ? Icon(Icons.chevron_right)
              : ok
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : FilledButton.tonal(onPressed: onTap, child: Text(actionLabel ?? AppStrings.t('去开启'))),
          onTap: onTap,
        ),
      ),
    );
  }
}
