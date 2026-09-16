import 'package:flutter/material.dart';
import '../../../core/l10n.dart';

import '../categories/categories_tab.dart';
import '../compare/compare_tab.dart';
import '../settings/settings_tab.dart';
import 'stats_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = <Widget>[
    const StatsTab(),
    const CategoriesTab(),
    const CompareTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: Theme.of(context).colorScheme.primaryContainer,
        height: 66,
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), selectedIcon: Icon(Icons.bar_chart), label: AppStrings.t('统计')),
          NavigationDestination(
              icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: AppStrings.t('分类')),
          NavigationDestination(
              icon: Icon(Icons.compare_arrows_rounded), selectedIcon: Icon(Icons.compare_arrows), label: AppStrings.t('对比')),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: AppStrings.t('设置')),
        ],
      ),
    );
  }
}
