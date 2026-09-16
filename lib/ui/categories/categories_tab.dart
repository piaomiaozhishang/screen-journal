import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/l10n.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../apps/app_detail.dart';
import '../widgets/common.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cats = s.categories;
    final uncategorized = s.appsOfCategory(null);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('分类'), style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCategory(context, null),
        icon: Icon(Icons.add),
        label: Text(AppStrings.t('新建分类')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          _CategoryRow(
            name: AppStrings.t('未分类'),
            colorValue: 0xFF9E9E9E,
            icon: Icons.help_outline,
            count: uncategorized.length,
            protected: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoryAppsPage(categoryId: null)),
            ),
          ),
          const SizedBox(height: 8),
          for (final c in cats) ...[
            _CategoryRow(
              name: c.name,
              colorValue: c.colorValue,
              icon: cpIcon(c.iconCodePoint),
              iconPath: c.iconPath,
              count: s.appsOfCategory(c.id).length,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CategoryAppsPage(categoryId: c.id)),
              ),
              onEdit: () => _editCategory(context, c),
              onDelete: () => _confirmDelete(context, c),
            ),
            SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppStrings.t('删除分类')),
        content: Text('${AppStrings.t('确认删除「')}${c.name}${AppStrings.t('」吗？\n该分类下的应用不会被删除，会自动回到“未分类”。')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.t('取消'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.t('删除'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AppState>().deleteCategory(c.id);
    }
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final int colorValue;
  final IconData icon;
  final String? iconPath;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool protected;
  const _CategoryRow({
    required this.name,
    required this.colorValue,
    required this.icon,
    required this.count,
    required this.onTap,
    this.iconPath,
    this.onEdit,
    this.onDelete,
    this.protected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: Color(colorValue).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12)),
                child: iconPath != null && File(iconPath!).existsSync()
                    ? Image.file(File(iconPath!),
                        width: 42, height: 42, fit: BoxFit.cover)
                    : Icon(icon, color: Color(colorValue)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(name,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
              Text('$count', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
              const SizedBox(width: 4),
              if (!protected)
                PopupMenuButton<String>(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(AppStrings.t('编辑分类'))),
                    PopupMenuItem(value: 'delete', child: Text(AppStrings.t('删除分类'))),
                  ],
                ),
              if (protected) const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 分类下的应用列表 ----------------

class CategoryAppsPage extends StatefulWidget {
  final int? categoryId; // null=未分类
  const CategoryAppsPage({super.key, required this.categoryId});

  @override
  State<CategoryAppsPage> createState() => _CategoryAppsPageState();
}

class _CategoryAppsPageState extends State<CategoryAppsPage> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cat = widget.categoryId == null
        ? null
        : s.categories.where((c) => c.id == widget.categoryId).firstOrNull;
    final title = cat?.name ?? AppStrings.t('未分类');
    final apps = s.appsOfCategory(widget.categoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: AppStrings.t('添加应用到该分类'),
            icon: Icon(Icons.playlist_add),
            onPressed: () => _pickApps(context),
          ),
        ],
      ),
      body: apps.isEmpty
          ? EmptyState(
              icon: Icons.label_outline,
              text: widget.categoryId == null
                  ? AppStrings.t('所有应用都已分类\n新装应用会自动出现在这里')
                  : '${AppStrings.t('还没有应用归入「')}$title${AppStrings.t('」\n点击右上角添加')}',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: apps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = apps[i];
                final cats = s.categoryIdsOfApp(a.id);
                return Material(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AppDetailPage(appId: a.id)),
                      );
                      if (mounted) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          AppIcon(iconPath: a.iconPath, name: a.name, size: 38,
                              uninstalled: a.uninstalled),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 14.5, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 5,
                                  children: [
                                    for (final cid in cats)
                                      if (s.categories.where((c) => c.id == cid).isNotEmpty)
                                        Builder(builder: (_) {
                                          final c = s.categories.firstWhere((c) => c.id == cid);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Color(c.colorValue).withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(c.name,
                                                style: TextStyle(
                                                    fontSize: 10.5, color: Color(c.colorValue))),
                                          );
                                        }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (widget.categoryId != null)
                            IconButton(
                              tooltip: AppStrings.t('移出该分类'),
                              icon: Icon(Icons.close, size: 19),
                              onPressed: () {
                                s.toggleAppCategory(a.id, widget.categoryId!, false);
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickApps(context),
        icon: Icon(Icons.add),
        label: Text(AppStrings.t('添加应用')),
      ),
    );
  }

  Future<void> _pickApps(BuildContext context) async {
    final s = context.read<AppState>();
    final all = s.allApps();
    final inCat = widget.categoryId == null
        ? null
        : s.appsOfCategory(widget.categoryId).map((e) => e.id).toSet();
    final selected = <int>{
      ...?inCat,
    };
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        // 未分类页：展示“未分类”的应用供选择加入；分类页：展示全部应用
        final list = widget.categoryId == null
            ? s.appsOfCategory(null)
            : all;
        return _AppPickerSheet(
          apps: list,
          selected: selected,
          onSave: () {
            if (widget.categoryId != null) {
              s.setAppCategoriesBulk(widget.categoryId!, selected);
            }
            Navigator.pop(ctx);
            setState(() {});
          },
        );
      },
    );
    // 未分类页的选择需要询问加入哪个分类
    if (widget.categoryId == null && selected.isNotEmpty && context.mounted) {
      _askCategoryAndAssign(context, selected);
    }
  }

  Future<void> _askCategoryAndAssign(BuildContext context, Set<int> appIds) async {
    final s = context.read<AppState>();
    final cats = s.categories;
    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('请先新建一个分类'))),
      );
      return;
    }
    final cid = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(AppStrings.t('加入哪个分类？'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final c in cats)
              ListTile(
                leading: Icon(cpIcon(c.iconCodePoint), color: Color(c.colorValue)),
                title: Text(c.name),
                onTap: () => Navigator.pop(context, c.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (cid != null) {
      for (final id in appIds) {
        s.toggleAppCategory(id, cid, true);
      }
      setState(() {});
    }
  }
}

// ---------------- 添加应用：搜索 + A-Z 字母索引 ----------------

/// 取名称首字的分组字母（A-Z，中文按拼音首字母，无法识别归 #）
String _nameInitial(String name) {
  final s = name.trim();
  if (s.isEmpty) return '#';
  final first = s[0];
  if (RegExp(r'[A-Za-z]').hasMatch(first)) return first.toUpperCase();
  final py = PinyinHelper.getPinyin(first);
  if (py.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(py)) {
    return py[0].toUpperCase();
  }
  return '#';
}

int _initialRank(String l) => l == '#' ? 26 : l.codeUnitAt(0) - 65;

class _AppPickerSheet extends StatefulWidget {
  final List<AppEntry> apps;
  final Set<int> selected;
  final VoidCallback onSave;
  const _AppPickerSheet({
    required this.apps,
    required this.selected,
    required this.onSave,
  });

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  String _query = '';
  final Map<String, GlobalKey> _sectionKeys = {};

  List<AppEntry> _filtered() {
    final q = _query.trim().toLowerCase();
    Iterable<AppEntry> list = widget.apps;
    if (q.isNotEmpty) {
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.package.toLowerCase().contains(q));
    }
    final out = list.toList()
      ..sort((a, b) {
        final ra = _initialRank(_nameInitial(a.name));
        final rb = _initialRank(_nameInitial(b.name));
        if (ra != rb) return ra.compareTo(rb);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return out;
  }

  /// 按首字母分组（保持排序）
  Map<String, List<AppEntry>> _groups(List<AppEntry> list) {
    final g = <String, List<AppEntry>>{};
    for (final a in list) {
      final l = _nameInitial(a.name);
      (g[l] ??= <AppEntry>[]).add(a);
    }
    final keys = g.keys.toList()
      ..sort((x, y) => _initialRank(x).compareTo(_initialRank(y)));
    return {for (final k in keys) k: g[k]!};
  }

  void _jumpTo(ScrollController controller, Map<String, List<AppEntry>> groups,
      List<String> keys, String letter) {
    if (!keys.contains(letter)) return;
    var offset = 0.0;
    for (final k in keys) {
      if (k == letter) break;
      offset += 30.0 + groups[k]!.length * 58.0;
    }
    final maxExtent = controller.position.maxScrollExtent;
    controller.jumpTo(offset.clamp(0.0, maxExtent));
    // 懒加载的目标分组构建后再精确对齐
    Future.delayed(const Duration(milliseconds: 90), () {
      final kctx = _sectionKeys[letter]?.currentContext;
      if (kctx != null && kctx.mounted) {
        Scrollable.ensureVisible(kctx,
            duration: const Duration(milliseconds: 200),
            alignment: 0,
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _query.trim().isNotEmpty;
    final list = _filtered();
    final groups = _groups(list);
    final keys = groups.keys.toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(AppStrings.t('选择应用（可跨分类多选）'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: AppStrings.t('搜索应用'),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (list.isEmpty)
                  Center(
                    child: Text(AppStrings.t('无匹配应用'),
                        style:
                            TextStyle(color: scheme.onSurface.withValues(alpha: 0.45))),
                  )
                else
                  ListView(
                    controller: controller,
                    padding: const EdgeInsets.only(right: 24, bottom: 12),
                    children: [
                      if (searching)
                        for (final a in list) _appTile(a)
                      else
                        for (final k in keys) ...[
                          Container(
                            key: _sectionKeys.putIfAbsent(k, () => GlobalKey()),
                            padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
                            alignment: Alignment.centerLeft,
                            child: Text(k,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.primary)),
                          ),
                          for (final a in groups[k]!) _appTile(a),
                        ],
                    ],
                  ),
                if (!searching && keys.isNotEmpty)
                  Positioned(
                    right: 1,
                    top: 6,
                    bottom: 6,
                    child: Center(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        decoration: BoxDecoration(
                          color:
                              scheme.surfaceContainerHighest.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final k in keys)
                              InkWell(
                                onTap: () => _jumpTo(controller, groups, keys, k),
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 18,
                                  height: keys.length > 20 ? 15 : 19,
                                  child: Center(
                                    child: Text(k,
                                        style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.primary)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onSave,
                child: Text(AppStrings.t('保存')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appTile(AppEntry a) {
    return CheckboxListTile(
      value: widget.selected.contains(a.id),
      onChanged: (v) => setState(() {
        if (v == true) {
          widget.selected.add(a.id);
        } else {
          widget.selected.remove(a.id);
        }
      }),
      secondary: AppIcon(
          iconPath: a.iconPath, name: a.name, size: 36,
          uninstalled: a.uninstalled),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(a.package,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5)),
    );
  }
}

// ---------------- 新建 / 编辑分类 ----------------

const _kPalette = [
  0xFF7E57C2, 0xFFEC407A, 0xFF42A5F5, 0xFF26A69A, 0xFF66BB6A,
  0xFFFFCA28, 0xFFEF5350, 0xFF8D6E63, 0xFF78909C, 0xFFFF7043,
  0xFF5C6BC0, 0xFF26C6DA,
];

const _kIcons = [
  Icons.sports_esports, Icons.videogame_asset, Icons.auto_stories, Icons.menu_book,
  Icons.animation, Icons.live_tv, Icons.movie, Icons.music_note, Icons.headphones,
  Icons.shopping_bag, Icons.school, Icons.work, Icons.chat, Icons.camera_alt,
  Icons.image, Icons.public, Icons.code, Icons.design_services, Icons.fitness_center,
  Icons.restaurant, Icons.travel_explore, Icons.child_friendly, Icons.apps,
];

Future<void> _editCategory(BuildContext context, Category? existing) async {
  final nameCtl = TextEditingController(text: existing?.name ?? '');
  var color = existing?.colorValue ?? _kPalette.first;
  var icon = existing?.iconCodePoint ?? Icons.label.codePoint;
  var iconPath = existing?.iconPath;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? AppStrings.t('新建分类') : AppStrings.t('编辑分类'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                SizedBox(height: 16),
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('分类名称'),
                    hintText: AppStrings.t('例如：学习、社交、购物…'),
                  ),
                ),
                SizedBox(height: 18),
                Text(AppStrings.t('自定义图标'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: Color(color).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12)),
                      child: iconPath != null && File(iconPath!).existsSync()
                          ? Image.file(File(iconPath!), width: 48, height: 48, fit: BoxFit.cover)
                          : Icon(cpIcon(icon), size: 24, color: Color(color)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(AppStrings.t('选择图片')),
                      onPressed: () async {
                        try {
                          final path = await _pickCategoryImage(existing?.id);
                          if (path != null) setSheet(() => iconPath = path);
                        } catch (_) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(AppStrings.t('图片选择失败，请重试'))),
                            );
                          }
                        }
                      },
                    ),
                    if (iconPath != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: AppStrings.t('清除'),
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setSheet(() => iconPath = null),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 18),
                Text(AppStrings.t('颜色'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _kPalette)
                      GestureDetector(
                        onTap: () => setSheet(() => color = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                                width: color == c ? 3 : 0,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                          ),
                          child: color == c
                              ? Icon(Icons.check, size: 17, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 18),
                Text(AppStrings.t('图标'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ic in _kIcons)
                      GestureDetector(
                        onTap: () => setSheet(() {
                          icon = ic.codePoint;
                          iconPath = null;
                        }),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: icon == ic.codePoint && iconPath == null
                                ? Color(color).withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(ic,
                              size: 20,
                              color: icon == ic.codePoint && iconPath == null
                                  ? Color(color)
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtl.text.trim();
                      if (name.isEmpty) return;
                      context.read<AppState>().saveCategory(
                            id: existing?.id,
                            name: name,
                            color: color,
                            icon: icon,
                            iconPath: iconPath,
                          );
                      Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? AppStrings.t('创建') : AppStrings.t('保存')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 选图 -> 方形裁剪 -> 存入应用目录，返回本地路径；用户取消返回 null，失败抛异常。
Future<String?> _pickCategoryImage(int? categoryId) async {
  final XFile? picked;
  try {
    // 限制读入尺寸，避免超大照片解码 OOM；不读取媒体位置等元数据，规避权限问题
    picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 92,
      requestFullMetadata: false,
    );
  } catch (e) {
    throw Exception('gallery unavailable');
  }
  if (picked == null) return null;

  var srcPath = picked.path;
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: AppStrings.t('裁剪图片'),
          toolbarColor: const Color(0xFF1F9E89),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          backgroundColor: const Color(0xFF111413),
        ),
        IOSUiSettings(
          title: AppStrings.t('裁剪图片'),
          aspectRatioLockEnabled: true,
          minimumAspectRatio: 1.0,
        ),
      ],
    );
    // 裁剪取消或失败时退回原图，不让流程中断
    if (cropped != null) srcPath = cropped.path;
  } catch (_) {
    srcPath = picked.path;
  }

  final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}cat_icons');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final dest =
      '${dir.path}${Platform.pathSeparator}cat_${categoryId ?? DateTime.now().millisecondsSinceEpoch}.png';
  await File(srcPath).copy(dest);
  return dest;
}
