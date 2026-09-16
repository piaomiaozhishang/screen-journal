import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n.dart';
import 'state/app_state.dart';
import 'ui/home/home_shell.dart';
import 'ui/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(
    ChangeNotifierProvider.value(
      value: state..init(),
      child: const JournalApp(),
    ),
  );
}

ThemeData buildTheme(int seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Color(seed),
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF111413) : const Color(0xFFF6F8F8),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF1C211F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF232927) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF171C1A) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
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
