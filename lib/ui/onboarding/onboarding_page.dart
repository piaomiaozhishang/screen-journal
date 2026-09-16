import 'package:flutter/material.dart';
import '../../../core/l10n.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with WidgetsBindingObserver {
  final _pc = PageController();
  int _page = 0;

  bool _usage = false;
  bool _battery = false;
  bool _overlay = false;
  bool _accessibility = false;
  bool _notification = true;
  bool _importing = false;
  String _importResult = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final n = context.read<AppState>().native;
    final vals = await Future.wait([
      n.hasUsagePermission(),
      n.isIgnoringBattery(),
      n.canDrawOverlays(),
      n.isAccessibilityEnabled(),
      n.notificationsEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _usage = vals[0];
      _battery = vals[1];
      _overlay = vals[2];
      _accessibility = vals[3];
      _notification = vals[4];
    });
  }

  void _next() {
    _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _back() {
    if (_page == 0) return;
    _pc.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    final s = context.read<AppState>();
    if (s.native.isAndroid) {
      await s.setMonitorEnabled(true);
    } else {
      await s.native.setAutoStart(true);
    }
    if (!s.historyImported) {
      await s.collectNow();
    }
    s.setOnboardingDone();
  }

  Future<void> _doImport() async {
    final s = context.read<AppState>();
    setState(() {
      _importing = true;
      _importResult = AppStrings.t('正在读取系统保留的历史记录…');
    });
    final r = await s.importHistory();
    if (!mounted) return;
    setState(() {
      _importing = false;
      if (r.error != null) {
        _importResult = '${AppStrings.t('导入失败：')}${r.error}';
      } else {
        _importResult = AppStrings.importedDays(r.daysChanged);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isWindows = s.native.isWindows;
    final steps = <_Step>[
      _Step(
        icon: Icons.timer_outlined,
        title: AppStrings.t('欢迎使用屏记'),
        desc: AppStrings.t('一款“永久记录”的屏幕时间账本：\n\n')
            + AppStrings.t('• 自带游戏 / 小说 / 动漫 / 影视分类，可随意增删改\n')
            + AppStrings.t('• 一个应用可以贴多个分类标签，卸载后数据永不丢失\n')
            + AppStrings.t('• 日、周、月、年、永久统计，支持评分、来源链接与使用限额\n')
            + AppStrings.t('• WebDAV 手动增量同步，手机与电脑数据合并不覆盖'),
        actionText: null,
      ),
      if (!isWindows)
        _Step(
          icon: Icons.insights,
          title: AppStrings.t('授予“使用情况访问权限”'),
          desc: AppStrings.t('这是屏幕时间统计的核心权限，屏记需要它读取各应用的前台使用时长。\n\n')
              + AppStrings.t('点击下方按钮 → 在系统列表中找到「屏记」→ 允许使用情况访问。'),
          actionText: _usage ? AppStrings.t('已开启') : AppStrings.t('去开启'),
          done: _usage,
          onAction: () => s.native.requestUsagePermission(),
        ),
      if (!isWindows)
        _Step(
          icon: Icons.history,
          title: AppStrings.t('导入已有使用时间'),
          desc: AppStrings.t('不必从零开始：屏记可以读取手机系统已经记录的应用使用时间（通常可回溯数月，')
              + AppStrings.t('因厂商而异），并与之后的记录永久叠加。\n\n建议现在导入，之后也可以在设置中再次操作。'),
          actionText: _importing ? AppStrings.t('导入中…') : (s.historyImported ? AppStrings.t('重新导入') : AppStrings.t('立即导入历史记录')),
          onAction: _importing ? null : _doImport,
          statusText: _importResult,
        ),
      if (!isWindows)
        _Step(
          icon: Icons.battery_saver,
          title: AppStrings.t('关闭电池优化（保持后台统计）'),
          desc: AppStrings.t('把屏记加入电池优化白名单，避免系统杀死后台统计服务。\n\n')
              + AppStrings.t('部分国产系统还需要在“自启动管理”中允许屏记自启动，可一并设置。'),
          actionText: _battery ? AppStrings.t('电池白名单已设置') : AppStrings.t('加入电池白名单'),
          done: _battery,
          onAction: () => s.native.requestIgnoreBattery(),
          secondaryText: AppStrings.t('打开厂商自启动设置'),
          onSecondary: () => s.native.openAutoStartSettings(),
        ),
      if (!isWindows)
        _Step(
          icon: Icons.block,
          title: AppStrings.t('限额强提醒（可选）'),
          desc: AppStrings.t('当某个应用达到你设定的每日使用限额时，屏记会全屏提醒并回到桌面。\n\n')
              + AppStrings.t('需要两项权限：\n① 悬浮窗（全屏遮挡）\n② 无障碍服务（执行“回到桌面”）\n\n')
              + AppStrings.t('说明：受 Android 系统限制，普通应用无法强制关闭其他应用，')
              + AppStrings.t('这是无 root 下最严格的实现方式。'),
          actionText: _overlay ? AppStrings.t('悬浮窗已允许') : AppStrings.t('① 允许悬浮窗'),
          done: _overlay,
          onAction: () => s.native.requestOverlayPermission(),
          secondaryText: _accessibility ? AppStrings.t('无障碍已开启') : AppStrings.t('② 开启无障碍服务'),
          onSecondary: () => s.native.openAccessibilitySettings(),
          done2: _accessibility,
        ),
      if (!isWindows)
        _Step(
          icon: Icons.notifications_none,
          title: AppStrings.t('通知权限（可选）'),
          desc: AppStrings.t('后台统计服务需要显示一条常驻通知，以保证稳定运行。请允许通知。'),
          actionText: _notification ? AppStrings.t('已允许') : AppStrings.t('开启通知'),
          done: _notification,
          onAction: () => s.native.openNotificationSettings(),
        ),
      if (isWindows)
        _Step(
          icon: Icons.desktop_windows_outlined,
          title: AppStrings.t('Windows 端说明'),
          desc: AppStrings.t('Windows 端会从前台活动窗口记录各软件使用时间，按 exe 识别应用，')
              + AppStrings.t('统计、分类、限额、图表与 WebDAV 同步功能与手机端一致。\n\n')
              + AppStrings.t('可选择开机自动启动屏记。'),
          actionText: AppStrings.t('设置开机自启'),
          onAction: () => s.native.setAutoStart(true),
        ),
      _Step(
        icon: Icons.verified_outlined,
        title: AppStrings.t('准备就绪'),
        desc: isWindows
            ? AppStrings.t('点击完成进入屏记，统计将从现在开始。')
            : AppStrings.t('点击完成后屏记将开始后台统计。你随时可以在「设置 → 权限管理」中调整这些权限。'),
        actionText: AppStrings.t('完成，进入屏记'),
        onAction: _finish,
        isFinish: true,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _StepView(step: steps[i]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(onPressed: _back, child: Text(AppStrings.t('上一步')))
                  else
                    const SizedBox(width: 72),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      steps.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Spacer(),
                  if (_page < steps.length - 1)
                    FilledButton(
                      onPressed: _next,
                      child: Text(AppStrings.t('下一步')),
                    )
                  else
                    const SizedBox(width: 72),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String desc;
  final String? actionText;
  final VoidCallback? onAction;
  final bool done;
  final String? secondaryText;
  final VoidCallback? onSecondary;
  final bool done2;
  final String? statusText;
  final bool isFinish;
  _Step({
    required this.icon,
    required this.title,
    required this.desc,
    this.actionText,
    this.onAction,
    this.done = false,
    this.secondaryText,
    this.onSecondary,
    this.done2 = false,
    this.statusText,
    this.isFinish = false,
  });
}

class _StepView extends StatelessWidget {
  final _Step step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(step.icon, size: 44, color: cs.primary),
            ),
          ),
          const SizedBox(height: 26),
          Text(step.title,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 14),
          Text(step.desc, style: TextStyle(fontSize: 14.5, height: 1.75, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87))),
          if (step.statusText != null) ...[
            const SizedBox(height: 14),
            Text(step.statusText!, style: TextStyle(fontSize: 13, color: cs.primary, height: 1.5)),
          ],
          const SizedBox(height: 26),
          if (step.actionText != null)
            SizedBox(
              width: double.infinity,
              child: step.isFinish
                  ? FilledButton.icon(
                      onPressed: step.onAction,
                      icon: Icon(Icons.check_circle_outline),
                      label: Text(step.actionText!),
                    )
                  : FilledButton(
                      onPressed: step.onAction,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (step.done) Icon(Icons.check, size: 18),
                        if (step.done) const SizedBox(width: 6),
                        Text(step.actionText!),
                      ]),
                    ),
            ),
          if (step.secondaryText != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: step.onSecondary,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (step.done2) Icon(Icons.check, size: 18),
                  if (step.done2) const SizedBox(width: 6),
                  Text(step.secondaryText!),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
