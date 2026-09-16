import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'state/app_state.dart';
import 'ui/home/home_shell.dart';
import 'ui/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 单个页面构建异常时显示克制的错误占位，而不是整屏灰死
  ErrorWidget.builder = (details) {
    FlutterError.presentError(details);
    return const _BuildErrorPlaceholder();
  };
  // 应用图标较多，收紧图片内存缓存，降低长时间使用后的内存压力
  PaintingBinding.instance.imageCache.maximumSize = 400;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20;
  final state = AppState();
  runApp(
    ChangeNotifierProvider.value(
      value: state..init(),
      child: const JournalApp(),
    ),
  );
}

class _BuildErrorPlaceholder extends StatelessWidget {
  const _BuildErrorPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Icon(Icons.error_outline,
          size: 38, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.55)),
    );
  }
}

/// 整套界面配色全部由 ColorScheme 派生：更换种子色时，背景、卡片、
/// 导航栏、输入框、弹窗等都会整体改变色调，而不只是强调色。
ThemeData buildTheme(int seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Color(seed),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(14))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      elevation: 3,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: scheme.outlineVariant,
  );
}

class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    AppStrings.lang = s.appLanguage == 'en' ? 'en' : 'zh';
    final seed = s.themeSeed;
    final locale = switch (s.appLanguage) {
      'zh' => const Locale('zh', 'CN'),
      'en' => const Locale('en'),
      _ => null, // 跟随系统
    };
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(seed, Brightness.light),
      darkTheme: buildTheme(seed, Brightness.dark),
      themeMode: s.themeMode,
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.ready) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (s.initError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.t('启动失败'))),
        body: Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('${AppStrings.t('初始化失败：\n')}${s.initError}', textAlign: TextAlign.start))),
      );
    }
    if (!s.onboardingDone) {
      return const OnboardingPage();
    }
    return const HomeShell();
  }
}
