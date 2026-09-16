import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n.dart';
import '../../state/app_state.dart';

/// GitHub 仓库信息
class RepoInfo {
  static const String homepage = 'https://github.com/piaomiaozhishang/screen-journal';
  static const String releases = 'https://github.com/piaomiaozhishang/screen-journal/releases';
  static bool get configured => homepage.isNotEmpty && !homepage.endsWith('/github.com/');
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('关于屏记'), style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Column(children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(Icons.timeline_rounded,
                    size: 42, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(AppStrings.appName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${AppStrings.t('版本')} ${AppState.appVersion}',
                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
            ]),
          ),
          const SizedBox(height: 20),
          _tile(context, Icons.code_rounded, AppStrings.t('GitHub 开源'),
              subtitle: AppStrings.t('项目主页与下载'),
              onTap: () => _open(context, RepoInfo.homepage)),
          _tile(context, Icons.system_update_alt, AppStrings.t('检查更新'),
              subtitle: AppStrings.t('前往 GitHub Releases 页检查是否有新版本。'),
              onTap: () => _open(context, RepoInfo.releases)),
          _tile(context, Icons.description_outlined, AppStrings.t('开源许可证'),
              subtitle: AppStrings.t('本项目基于 MIT 许可证开源。'),
              onTap: () => _showLicense(context)),
          _tile(context, Icons.favorite_border, AppStrings.t('赞赏支持'),
              subtitle: AppStrings.t('如果你喜欢屏记，可以请我喝杯咖啡支持继续开发。'),
              onTap: () => _showDonate(context)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              AppStrings.t('屏记 · 屏幕时间记录 v1.0.3\n')
              + AppStrings.t('数据默认保存在本机；卸载应用 / 清除数据会丢失统计，请定期使用备份或 WebDAV 同步。\n')
              + AppStrings.t('统计自安装本应用起永久保留，并可导入系统已有的历史记录。'),
              style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  height: 1.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      {String? subtitle, required VoidCallback onTap}) {
    return Card(
      color: Theme.of(context).cardTheme.color,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
        trailing: Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    if (!RepoInfo.configured) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.t('仓库地址即将发布'))));
      }
      return;
    }
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('打开失败'))));
    }
  }

  void _showLicense(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('MIT License'),
        content: const SingleChildScrollView(
          child: Text(
            'MIT License\n\n'
            'Copyright (c) 2026 Screen Journal Contributors\n\n'
            'Permission is hereby granted, free of charge, to any person obtaining a copy\n'
            'of this software and associated documentation files (the "Software"), to deal\n'
            'in the Software without restriction, including without limitation the rights\n'
            'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n'
            'copies of the Software, and to permit persons to whom the Software is\n'
            'furnished to do so, subject to the following conditions:\n\n'
            'The above copyright notice and this permission notice shall be included in all\n'
            'copies or substantial portions of the Software.\n\n'
            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
            'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
            'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n'
            'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n'
            'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n'
            'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n'
            'SOFTWARE.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t('取消'))),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK')),
        ],
      ),
    );
  }

  void _showDonate(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
        title: Text(AppStrings.t('赞赏支持')),
        content: Text(
          AppStrings.t('如果你喜欢屏记，可以请我喝杯咖啡支持继续开发。'),
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t('取消'))),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t('好的'))),
        ],
      ),
    );
  }
}
