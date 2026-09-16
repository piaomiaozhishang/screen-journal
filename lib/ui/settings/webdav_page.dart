import 'package:flutter/material.dart';
import '../../../core/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

class WebDavPage extends StatefulWidget {
  const WebDavPage({super.key});

  @override
  State<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends State<WebDavPage> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  late final TextEditingController _pwd;
  late final TextEditingController _root;
  late final TextEditingController _name;
  bool _busy = false;
  String? _report;
  bool _reportOk = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _url = TextEditingController(text: s.webdavUrl ?? '');
    _user = TextEditingController(text: s.webdavUser ?? '');
    _pwd = TextEditingController(text: s.webdavPassword ?? '');
    _root = TextEditingController(text: s.webdavRoot);
    _name = TextEditingController(text: s.deviceName);
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pwd.dispose();
    _root.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final s = context.read<AppState>();
    s.saveWebDavConfig(
      url: _url.text,
      user: _user.text,
      password: _pwd.text,
      root: _root.text,
      name: _name.text,
    );
    if (_url.text.trim().isEmpty) {
      setState(() {
        _report = AppStrings.t('请先填写 WebDAV 服务器地址');
        _reportOk = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _report = AppStrings.t('正在连接并同步…');
      _reportOk = false;
    });
    final r = await s.syncWebDav();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reportOk = r.ok;
      _report = r.ok
          ? '${AppStrings.t('同步成功：合并了')}${r.remoteDevices}${AppStrings.t(' 台设备、')}'
              '${r.remoteDays}${AppStrings.t(' 条远端统计，')}'
              '${AppStrings.t('上传本机')}${r.uploadedDays}${AppStrings.t(' 条统计。')}'
          : '${AppStrings.t('同步失败：')}${r.error}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('WebDAV 同步'))),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.t('同步规则'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text(
                  AppStrings.t('• 手动点击“立即同步”，不会自动同步\n')
                  + AppStrings.t('• 只同步应用使用时间统计，按“设备 + 天”增量合并，只增不覆盖、不删除\n')
                  + AppStrings.t('• 分类、评分、描述、来源、限额等个人编辑不会同步\n')
                  + AppStrings.t('• 手机与电脑可登录同一个 WebDAV 账号互通'),
                  style: TextStyle(fontSize: 12.5, height: 1.8, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)),
                ),
                Divider(height: 24),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('本机名称'),
                    hintText: AppStrings.t('用于在多设备中识别'),
                    prefixIcon: Icon(Icons.devices, size: 19),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('WebDAV 服务器地址'),
                    hintText: AppStrings.t('例如 https://dav.example.com/user/ '),
                    prefixIcon: Icon(Icons.dns_outlined, size: 19),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _user,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('用户名'),
                    prefixIcon: Icon(Icons.person_outline, size: 19),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _pwd,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('密码 / 应用专用密码'),
                    hintText: AppStrings.t('坚果云等需使用“应用密码”'),
                    prefixIcon: Icon(Icons.lock_outline, size: 19),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _root,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('服务器上的同步目录'),
                    hintText: 'screentime',
                    prefixIcon: Icon(Icons.folder_outlined, size: 19),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _sync,
            icon: _busy
                ? SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.sync),
            label: Text(_busy ? AppStrings.t('同步中…') : AppStrings.t('测试连接并立即同步')),
          ),
          if (_report != null) ...[
            const SizedBox(height: 14),
            SectionCard(
              color: _reportOk
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(_reportOk ? Icons.check_circle_outline : Icons.error_outline,
                      color: _reportOk
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).colorScheme.onErrorContainer,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_report!,
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: _reportOk
                                ? Theme.of(context).colorScheme.onSecondaryContainer
                                : Theme.of(context).colorScheme.onErrorContainer)),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 14),
          if (s.lastSyncMs != null)
            Text(
                AppStrings.lastSynced(Fmt.dateCn(DateTime.fromMillisecondsSinceEpoch(int.parse(s.lastSyncMs!)))),
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
          SizedBox(height: 10),
          Text(
            AppStrings.t('支持兼容标准 WebDAV 协议的网盘/自建服务（坚果云、群晖、Nextcloud 等）；')
            + AppStrings.t('夸克网盘等若未提供 WebDAV 地址，则不能直接用于同步，可改用其支持 WebDAV 的客户端中转。'),
            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), height: 1.6),
          ),
        ],
      ),
    );
  }
}
