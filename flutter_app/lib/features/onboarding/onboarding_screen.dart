import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.search_rounded,
      titlePT: 'Busca por Cenário',
      titleEN: 'Scenario Search',
      descPT: 'Descreve o que estás a sentir\ne a IA encontra os versículos\nmais relevantes para ti.',
      descEN: 'Describe how you feel\nand AI finds the most\nrelevant verses for you.',
      gradient: AppColors.primaryGradient,
    ),
    _OnboardingPage(
      icon: Icons.menu_book_rounded,
      titlePT: 'Leitura com Contexto',
      titleEN: 'Contextual Reading',
      descPT: 'Lê a Bíblia completa com\ncontexto histórico e significados\nem grego e hebraico.',
      descEN: 'Read the complete Bible with\nhistorical context and meanings\nin Greek and Hebrew.',
      gradient: LinearGradient(
        colors: [Color(0xFF2D6A8F), Color(0xFF4A9BC9)],
      ),
    ),
    _OnboardingPage(
      icon: Icons.auto_stories_rounded,
      titlePT: 'Gerador de Esboços',
      titleEN: 'Sermon Generator',
      descPT: 'Gera esboços completos de\npregação com introdução, pontos,\nilustrações e oração.',
      descEN: 'Generate complete sermon\noutlines with introduction, points,\nillustrations and prayer.',
      gradient: AppColors.goldGradient,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    await ref.read(settingsProvider.notifier).completeOnboarding();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isPT = ref.watch(settingsProvider).language == 'pt';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    isPT ? 'Saltar' : 'Skip',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: page.gradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon,
                              color: Colors.white, size: 56),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          isPT ? page.titlePT : page.titleEN,
                          style: theme.textTheme.displayMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isPT ? page.descPT : page.descEN,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primary
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Next / Get started button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? (isPT ? 'Próximo' : 'Next')
                            : (isPT ? 'Começar' : 'Get Started'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titlePT;
  final String titleEN;
  final String descPT;
  final String descEN;
  final Gradient gradient;

  const _OnboardingPage({
    required this.icon,
    required this.titlePT,
    required this.titleEN,
    required this.descPT,
    required this.descEN,
    required this.gradient,
  });
}
