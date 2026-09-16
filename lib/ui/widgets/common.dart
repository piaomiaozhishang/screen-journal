import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/dates.dart';

/// 用数据库存储的码点构造 Material 图标（运行时码点）。
/// 所有可供选择的分类图标均在 categories 页的 const _kIcons 中被常量引用，
/// 因此 release 图标树摇不会移除这些字形。
IconData cpIcon(int codePoint) =>
    // ignore: non_const_argument_for_const_parameter
    IconData(codePoint, fontFamily: 'MaterialIcons');

/// 应用图标：优先本地缓存图片，否则显示首字头像。
class AppIcon extends StatelessWidget {
  final String? iconPath;
  final String name;
  final double size;
  final Color? fallbackColor;
  final int uninstalled;
  const AppIcon({
    super.key,
    required this.iconPath,
    required this.name,
    this.size = 40,
    this.fallbackColor,
    this.uninstalled = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = fallbackColor ?? Theme.of(context).colorScheme.primaryContainer;
    Widget child;
    if (iconPath != null && iconPath!.isNotEmpty && File(iconPath!).existsSync()) {
      // cacheWidth 按显示尺寸缩小解码，避免全尺寸位图占用内存与解码时间
      child = Image.file(File(iconPath!), width: size, height: size, fit: BoxFit.cover,
          cacheWidth: (size * 3).round(), cacheHeight: (size * 3).round(),
          errorBuilder: (_, _, _) => _fallback(color, context));
    } else {
      child = _fallback(color, context);
    }
    child = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: child,
    );
    if (uninstalled == 1) {
      child = Opacity(opacity: 0.55, child: child);
    }
    return SizedBox(width: size, height: size, child: child);
  }

  Widget _fallback(Color color, BuildContext context) {
    final ch = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(ch,
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87))),
    );
  }
}

/// 主题色快捷函数：在无 BuildContext 的回调中使用
Color onSurface(BuildContext context, double alpha) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha);

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const SectionCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// 日 / 周 / 月 / 年 / 永久 区间切换
class RangeSelector extends StatelessWidget {
  final TimeRange value;
  final ValueChanged<TimeRange> onChanged;
  final bool allowForever;
  const RangeSelector(
      {super.key, required this.value, required this.onChanged, this.allowForever = true});

  @override
  Widget build(BuildContext context) {
    final vals = TimeRange.values.where((r) => allowForever || r != TimeRange.forever).toList();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final r in vals)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == r ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(r.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == r ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                      )),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final String? hint;
  const StatTile({super.key, required this.label, required this.value, this.icon, this.hint});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)))],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.text, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.26)),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45), fontSize: 14, height: 1.5)),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(onPressed: onAction, child: Text(actionText!)),
            ]
          ],
        ),
      ),
    );
  }
}

class CategoryDot extends StatelessWidget {
  final int colorValue;
  final double size;
  const CategoryDot({super.key, required this.colorValue, this.size = 10});

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: Color(colorValue), shape: BoxShape.circle));
}
