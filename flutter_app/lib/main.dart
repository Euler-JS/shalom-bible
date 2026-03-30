import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/bible_database.dart';
import 'data/remote/openai_service.dart';
import 'features/scenario_search/scenario_search_screen.dart';
import 'features/reading/reading_screen.dart';
import 'features/sermon_generator/sermon_generator_screen.dart';
import 'features/library/library_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Bible database (copies SQLite assets on first run)
  await BibleDatabase.instance.init();

  // Pre-load dev API key if set and not yet stored
  if (AppConstants.openAiDevKey.isNotEmpty) {
    final hasKey = await OpenAIService.instance.hasApiKey();
    if (!hasKey) {
      await OpenAIService.instance.saveApiKey(AppConstants.openAiDevKey);
    }
  }

  runApp(const ProviderScope(child: ShalomBibleApp()));
}

class ShalomBibleApp extends ConsumerWidget {
  const ShalomBibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Shalom Bible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    if (!settings.onboardingDone) {
      return OnboardingScreen(
        onComplete: () {
          // Settings notifier updates state — widget rebuilds automatically
        },
      );
    }

    return const MainNavigation();
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 1; // Start on Reading tab

  final List<Widget> _screens = const [
    ScenarioSearchScreen(),
    ReadingScreen(),
    SermonGeneratorScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withAlpha(20),
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.search_outlined),
              selectedIcon:
                  const Icon(Icons.search_rounded, color: AppColors.primary),
              label: isPT ? 'Cenários' : 'Scenarios',
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book_rounded,
                  color: AppColors.primary),
              label: isPT ? 'Leitura' : 'Reading',
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: const Icon(Icons.auto_stories_rounded,
                  color: AppColors.primary),
              label: isPT ? 'Esboço' : 'Sermon',
            ),
            NavigationDestination(
              icon: const Icon(Icons.library_books_outlined),
              selectedIcon: const Icon(Icons.library_books_rounded,
                  color: AppColors.primary),
              label: isPT ? 'Biblioteca' : 'Library',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'settings_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.settings_outlined, size: 20),
      ),
    );
  }
}
