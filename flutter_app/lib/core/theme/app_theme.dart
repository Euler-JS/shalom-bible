import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand colours (never change between light/dark) ─────────────────────────
class AppColors {
  static const primary = Color(0xFF3B2D8F);
  static const secondary = Color(0xFFC9A84C);
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);

  // kept for onboarding / gradients / non-adaptive use
  static const background = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF7F6FB);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B6B8A);
  static const divider = Color(0xFFE8E6F0);
  static const cardBorder = Color(0xFFEAE8F5);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B2D8F), Color(0xFF5A47C2)],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9A84C), Color(0xFFE5C76D)],
  );
}

// ─── Adaptive colours (change with theme) ────────────────────────────────────
class AppAdaptiveColors extends ThemeExtension<AppAdaptiveColors> {
  const AppAdaptiveColors({
    required this.background,
    required this.surface,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.cardBorder,
    required this.inputFill,
  });

  final Color background;
  final Color surface;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color cardBorder;
  final Color inputFill;

  static const light = AppAdaptiveColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F6FB),
    cardBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B6B8A),
    divider: Color(0xFFE8E6F0),
    cardBorder: Color(0xFFEAE8F5),
    inputFill: Color(0xFFF7F6FB),
  );

  static const dark = AppAdaptiveColors(
    background: Color(0xFF0F0E1A),
    surface: Color(0xFF1C1A2E),
    cardBackground: Color(0xFF1C1A2E),
    textPrimary: Color(0xFFF0EEFF),
    textSecondary: Color(0xFF9996B5),
    divider: Color(0xFF2C2A45),
    cardBorder: Color(0xFF2C2A45),
    inputFill: Color(0xFF1C1A2E),
  );

  @override
  AppAdaptiveColors copyWith({
    Color? background,
    Color? surface,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? cardBorder,
    Color? inputFill,
  }) =>
      AppAdaptiveColors(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        cardBackground: cardBackground ?? this.cardBackground,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        divider: divider ?? this.divider,
        cardBorder: cardBorder ?? this.cardBorder,
        inputFill: inputFill ?? this.inputFill,
      );

  @override
  AppAdaptiveColors lerp(AppAdaptiveColors? other, double t) {
    if (other == null) return this;
    return AppAdaptiveColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

// ─── Shortcut extension ───────────────────────────────────────────────────────
extension AppThemeX on BuildContext {
  AppAdaptiveColors get ac =>
      Theme.of(this).extension<AppAdaptiveColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── ThemeData ────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppAdaptiveColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppAdaptiveColors.dark);

  static ThemeData _build(Brightness brightness, AppAdaptiveColors ac) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: ac.background,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: ac.textPrimary,
        onSurface: ac.textPrimary,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: ac.background,
      extensions: [ac],
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.merriweather(
          fontSize: 28, fontWeight: FontWeight.bold, color: ac.textPrimary),
        displayMedium: GoogleFonts.merriweather(
          fontSize: 24, fontWeight: FontWeight.bold, color: ac.textPrimary),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w600, color: ac.textPrimary),
        titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: ac.textPrimary),
        titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w500, color: ac.textPrimary),
        bodyLarge: GoogleFonts.merriweather(
          fontSize: 17, height: 1.8, color: ac.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: ac.textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 13, color: ac.textSecondary),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5,
          color: ac.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: ac.background,
        foregroundColor: ac.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: ac.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ac.inputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: ac.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: ac.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ac.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: ac.divider, thickness: 1, space: 0),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ac.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: ac.textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ac.background,
        indicatorColor: AppColors.primary.withAlpha(isDark ? 40 : 20),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : ac.textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : ac.textSecondary,
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ac.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
