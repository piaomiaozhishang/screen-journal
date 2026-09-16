import 'package:flutter/material.dart';
import '../../../core/l10n.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/common.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.t('备份与恢复'))),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Text(AppStrings.t('备份内容'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                SizedBox(height: 8),
                Text(
                  AppStrings.t('手动备份为完整备份，包含：\n')
                  + AppStrings.t('• 全部应用的日 / 周 / 月 / 年 / 永久使用统计\n')
                  + AppStrings.t('• 分类与多标签、评分、描述、软件来源\n')
                  + AppStrings.t('• 安装日期、每日限额、卸载/重装记录\n')
                  + AppStrings.t('（WebDAV 同步仅同步统计数据，不含个人编辑）'),
                  style: TextStyle(fontSize: 12.5, height: 1.8),
                ),
              ],
            ),
          ),
          SizedBox(height: 14),
          FilledButton.icon(
            icon: Icon(Icons.file_upload_outlined),
            label: Text(AppStrings.t('导出完整备份文件（JSON）')),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final path = await s.exportBackup();
              if (path != null) {
                messenger.showSnackBar(SnackBar(
                    content: Text('${AppStrings.t('已导出')}：$path')));
              }
            },
          ),
          SizedBox(height: 10),
          OutlinedButton.icon(
            icon: Icon(Icons.file_download_outlined),
            label: Text(AppStrings.t('导入备份（增量合并，不覆盖本地编辑）')),
            onPressed: () => _import(context, false),
          ),
          SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: Icon(Icons.restore, color: Colors.red),
            label: Text(AppStrings.t('覆盖恢复（清空当前数据后还原，危险）')),
            onPressed: () => _import(context, true),
          ),
          SizedBox(height: 20),
          SectionCard(
            color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            child: Text(
              AppStrings.t('建议：换机或重装 App 前先导出备份；多台设备日常统计推荐使用 WebDAV 同步，')
              + AppStrings.t('备份文件用于长期归档或一次性迁移。'),
              style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: Theme.of(context).colorScheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, bool overwrite) async {
    final s = context.read<AppState>();
    if (overwrite) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppStrings.t('确认覆盖恢复？')),
          content: Text(AppStrings.t('将清空本机全部应用、分类、统计与编辑内容，然后用备份文件还原。')
              + AppStrings.t('建议先导出一份当前备份。此操作不可撤销。')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.t('取消'))),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppStrings.t('确认覆盖'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await s.importBackup(overwrite: overwrite);
      if (r != null) {
        messenger.showSnackBar(SnackBar(
            content: Text(AppStrings.importResult(
                r['categories'] as int, r['apps'] as int, r['daily'] as int))));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${AppStrings.t('导入失败：')}$e')));
    }
  }
}
