import 'package:flutter/material.dart';

/// Brand colours shared by the app's screens and navigation.
///
/// Clinical, trustworthy palette: teal primary on crisp off-white surfaces,
/// with clear semantic colours for stock and status states.
abstract final class AppColors {
  // Primary clinical accent (teal).
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF2DD4BF);

  // Supporting brand blues used by POS/approve actions.
  static const Color brandGreen = Color(0xFF0284C7);
  static const Color brandGreenSurface = Color(0xFFE0F2FE);
  static const Color brandGreenSurfaceBorder = Color(0xFFBAE6FD);

  // Surfaces.
  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);

  // Semantic status colours.
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Text.
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Legacy aliases kept for compatibility with existing call sites.
  static const Color primarySurface = Color(0xFFCCFBF1);
  static const Color primarySurfaceBorder = Color(0xFF99F6E4);
}

/// Tabular figures feature, used so digits align in prices/quantities.
const List<FontFeature> _tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

ThemeData buildAppTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  );
  final scheme = baseScheme.copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.brandGreen,
    onSecondary: Colors.white,
    surface: isLight ? AppColors.cardSurface : baseScheme.surface,
    onSurface: isLight ? AppColors.textPrimary : baseScheme.onSurface,
    surfaceContainerLowest: isLight ? Colors.white : baseScheme.surfaceContainerLowest,
    surfaceContainerLow: isLight ? AppColors.surfaceMuted : baseScheme.surfaceContainerLow,
    surfaceContainer: isLight ? AppColors.surfaceMuted : baseScheme.surfaceContainer,
    surfaceContainerHigh: isLight ? const Color(0xFFE2E8F0) : baseScheme.surfaceContainerHigh,
    surfaceContainerHighest: isLight ? const Color(0xFFCBD5E1) : baseScheme.surfaceContainerHighest,
    error: AppColors.danger,
    outline: isLight ? const Color(0xFFCBD5E1) : baseScheme.outline,
    outlineVariant: isLight ? const Color(0xFFE2E8F0) : baseScheme.outlineVariant,
  );

  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  // Base text styles using Inter.
  TextStyle t({
    required double size,
    required int weight,
    required Color color,
    double? height,
    double? letterSpacing,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? _tabularFigures : null,
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  // Convenience weight access
  final textTheme = TextTheme(
    displayLarge: t(size: 40, weight: 700, color: onSurface, letterSpacing: -1.0, height: 1.1),
    displayMedium: t(size: 34, weight: 700, color: onSurface, letterSpacing: -0.6, height: 1.15),
    displaySmall: t(size: 28, weight: 700, color: onSurface, letterSpacing: -0.4, height: 1.2),
    headlineLarge: t(size: 24, weight: 700, color: onSurface, letterSpacing: -0.3, height: 1.25),
    headlineMedium: t(size: 20, weight: 600, color: onSurface, letterSpacing: -0.2, height: 1.3),
    headlineSmall: t(size: 18, weight: 600, color: onSurface, letterSpacing: -0.1, height: 1.3),
    titleLarge: t(size: 18, weight: 600, color: onSurface, height: 1.3),
    titleMedium: t(size: 16, weight: 600, color: onSurface, height: 1.35),
    titleSmall: t(size: 14, weight: 600, color: onSurface, height: 1.35),
    bodyLarge: t(size: 16, weight: 400, color: onSurface, height: 1.5),
    bodyMedium: t(size: 14, weight: 400, color: onSurfaceVariant, height: 1.5),
    bodySmall: t(size: 12, weight: 400, color: onSurfaceVariant, height: 1.45),
    labelLarge: t(size: 14, weight: 600, color: onSurface, letterSpacing: 0.1, height: 1.2),
    labelMedium: t(size: 12, weight: 600, color: onSurface, letterSpacing: 0.2, height: 1.2),
    labelSmall: t(size: 11, weight: 500, color: onSurfaceVariant, letterSpacing: 0.3, height: 1.2),
  );

  // Tabular variants for numbers: provide via textTheme? We'll keep base; screens can use fontFeatures.
  // But make labelLarge/bodyMedium tabular by default? Prices use various. Add tabular to a couple.
  final tabularTextTheme = textTheme.copyWith(
    titleMedium: textTheme.titleMedium?.copyWith(fontFeatures: _tabularFigures),
    titleLarge: textTheme.titleLarge?.copyWith(fontFeatures: _tabularFigures),
    bodyLarge: textTheme.bodyLarge?.copyWith(fontFeatures: _tabularFigures),
    bodyMedium: textTheme.bodyMedium?.copyWith(fontFeatures: _tabularFigures),
    labelLarge: textTheme.labelLarge?.copyWith(fontFeatures: _tabularFigures),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: tabularTextTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      centerTitle: true,
      titleTextStyle: tabularTextTheme.titleLarge?.copyWith(color: onSurface),
      iconTheme: IconThemeData(color: onSurface),
    ),
    cardTheme: CardThemeData(
      color: isLight ? AppColors.cardSurface : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      indicatorColor:
          isLight ? AppColors.primarySurface : scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        tabularTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: AppColors.primary);
        }
        return IconThemeData(color: onSurfaceVariant);
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      labelStyle: tabularTextTheme.labelLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      contentTextStyle: TextStyle(color: scheme.surface, fontFamily: 'Inter'),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.surfaceMuted : scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: onSurfaceVariant, fontFamily: 'Inter'),
      hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Inter'),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: tabularTextTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: tabularTextTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: tabularTextTheme.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isLight ? AppColors.surfaceMuted : scheme.surfaceContainer,
      selectedColor: AppColors.primarySurface,
      labelStyle: tabularTextTheme.bodySmall?.copyWith(color: onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: scheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 16,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 8,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: onSurface,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: tabularTextTheme.labelLarge,
      ),
    ),
  );
}