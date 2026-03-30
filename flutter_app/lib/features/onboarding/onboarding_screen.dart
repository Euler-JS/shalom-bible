import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const _pages = [_welcome, _reading, _sermon];

  static const _welcome = _PageData(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2A1F6B), Color(0xFF3B2D8F), Color(0xFF1a1040)],
    ),
    icon: Icons.menu_book_rounded,
    titlePT: 'Shalom Bible',
    titleEN: 'Shalom Bible',
    subtitlePT: 'A Bíblia na tua língua.\nNo teu contexto.\nPara a tua vida.',
    subtitleEN: 'The Bible in your language.\nIn your context.\nFor your life.',
    features: [],
    accentColor: Color(0xFFC9A84C),
    isWelcome: true,
  );

  static const _reading = _PageData(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B4F6B), Color(0xFF2D7EA0), Color(0xFF0d3347)],
    ),
    icon: Icons.translate_rounded,
    titlePT: 'Cada Palavra\nTem Profundidade',
    titleEN: 'Every Word\nHas Depth',
    subtitlePT: 'Lê a Bíblia completa e descobre o que estava por detrás das palavras originais.',
    subtitleEN: 'Read the complete Bible and discover what was behind the original words.',
    features: [
      _Feature(Icons.abc, 'Hebraico & Grego', 'Hebrew & Greek'),
      _Feature(Icons.history_edu_rounded, 'Contexto histórico', 'Historical context'),
      _Feature(Icons.lightbulb_outline, 'Explicações simples', 'Simple explanations'),
    ],
    accentColor: Color(0xFF4AC9E3),
    isWelcome: false,
  );

  static const _sermon = _PageData(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5C3A0A), Color(0xFF8B6914), Color(0xFF3d2507)],
    ),
    icon: Icons.auto_stories_rounded,
    titlePT: 'Pregação com\nFundamento Real',
    titleEN: 'Preaching with\nReal Foundation',
    subtitlePT: 'Gera esboços completos com pontos, ilustrações e oração — em segundos.',
    subtitleEN: 'Generate complete outlines with points, illustrations and prayer — in seconds.',
    features: [
      _Feature(Icons.format_list_bulleted, 'Estrutura completa', 'Complete structure'),
      _Feature(Icons.format_quote_rounded, 'Histórias e ilustrações', 'Stories & illustrations'),
      _Feature(Icons.share_rounded, 'Partilha fácil', 'Easy sharing'),
    ],
    accentColor: Color(0xFFC9A84C),
    isWelcome: false,
  );

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _fadeCtrl.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _fadeCtrl.forward();
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
    final page = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(gradient: page.gradient),
        child: SafeArea(
          child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                  child: TextButton(
                    onPressed: _complete,
                    child: Text(
                      isPT ? 'Saltar' : 'Skip',
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) {
                    _fadeCtrl.reset();
                    setState(() => _currentPage = i);
                    _fadeCtrl.forward();
                  },
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _PageContent(
                    data: _pages[i],
                    isPT: isPT,
                    fadeAnim: _fadeAnim,
                  ),
                ),
              ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: Column(
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? page.accentColor
                                : Colors.white.withAlpha(60),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: page.accentColor,
                          foregroundColor: _currentPage == 3
                              ? Colors.white
                              : const Color(0xFF1a1040),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? (isPT ? 'Continuar' : 'Continue')
                              : (isPT ? 'Começar Agora' : 'Get Started'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _PageData data;
  final bool isPT;
  final Animation<double> fadeAnim;

  const _PageContent({
    required this.data,
    required this.isPT,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: data.isWelcome ? _buildWelcome() : _buildFeature(),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(10),
                ),
              ),
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(15),
                  border: Border.all(
                      color: data.accentColor.withAlpha(100), width: 1.5),
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'assets/images/icon_with_background.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            isPT ? data.titlePT : data.titleEN,
            style: GoogleFonts.merriweather(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            isPT ? data.subtitlePT : data.subtitleEN,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withAlpha(200),
              height: 1.8,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: data.accentColor.withAlpha(80)),
            ),
            child: Text(
              isPT ? 'Hebraico · Aramaico · Grego' : 'Hebrew · Aramaic · Greek',
              style: TextStyle(
                fontSize: 13,
                color: data.accentColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: data.accentColor.withAlpha(100)),
                ),
                child: Icon(data.icon, color: data.accentColor, size: 36),
              ),
              const SizedBox(width: 14),
              Image.asset(
                'assets/images/icon.png',
                width: 44,
                height: 44,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Title
          Text(
            isPT ? data.titlePT : data.titleEN,
            style: GoogleFonts.merriweather(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),

          // Subtitle
          Text(
            isPT ? data.subtitlePT : data.subtitleEN,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withAlpha(180),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 36),

          // Feature bullets
          ...data.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: data.accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(f.icon, color: data.accentColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      isPT ? f.labelPT : f.labelEN,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String labelPT;
  final String labelEN;

  const _Feature(this.icon, this.labelPT, this.labelEN);
}

class _PageData {
  final LinearGradient gradient;
  final IconData icon;
  final String titlePT;
  final String titleEN;
  final String subtitlePT;
  final String subtitleEN;
  final List<_Feature> features;
  final Color accentColor;
  final bool isWelcome;

  const _PageData({
    required this.gradient,
    required this.icon,
    required this.titlePT,
    required this.titleEN,
    required this.subtitlePT,
    required this.subtitleEN,
    required this.features,
    required this.accentColor,
    required this.isWelcome,
  });
}
