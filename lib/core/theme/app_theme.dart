import 'package:flutter/material.dart';

/// Brand colours shared by the app's screens and navigation.
///
/// Refined pharmacy palette: luminous emerald/teal paired with electric
/// cyan/aqua on soft mint-tinted surfaces, with clear semantic status tones.
abstract final class AppColors {
  // Primary clinical accent (emerald/teal).
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFF5EEAD4);

  // Secondary accent (electric cyan/aqua) used by POS/approve actions.
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color secondaryLight = Color(0xFF38BDF8);
  static const Color secondarySurface = Color(0xFFECFEFF);
  static const Color secondarySurfaceBorder = Color(0xFFA5F3FC);

  // Legacy alias kept for compatibility with existing call sites.
  static const Color brandGreen = Color(0xFF34D399);
  static const Color brandGreenSurface = Color(0xFFECFEFF);
  static const Color brandGreenSurfaceBorder = Color(0xFFA5F3FC);

  // Warm amber accent for highlights and warnings.
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentAmberSurface = Color(0xFFFEF3C7);
  static const Color accentAmberSurfaceBorder = Color(0xFFFCD34D);

  // Surfaces.
  static const Color pageBackground = Color(0xFF071B32);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFE6F7F4);
  static const Color surfaceTint = Color(0xFFD1FAE5);

  // Semantic status colours.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Text.
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);

  // Legacy aliases kept for compatibility with existing call sites.
  static const Color primarySurface = Color(0xFFD1FAE5);
  static const Color primarySurfaceBorder = Color(0xFFA7F3D0);
}

/// Tabular figures feature, used so digits align in prices/quantities.
const List<FontFeature> _tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

TextStyle _textStyle({
  required String fontFamily,
  required double size,
  required int weight,
  required Color color,
  double? height,
  double? letterSpacing,
  bool tabular = false,
}) {
  return TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100).clamp(1, 9) - 1],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: tabular ? _tabularFigures : null,
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  );
  final scheme = baseScheme.copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    tertiary: AppColors.accentAmber,
    onTertiary: Colors.white,
    surface: isLight ? AppColors.cardSurface : const Color(0xFF071B32),
    onSurface: isLight ? AppColors.textPrimary : const Color(0xFFF1F6FC),
    onSurfaceVariant: isLight ? AppColors.textSecondary : const Color(0xFF9FB5CC),
    surfaceContainerLowest:
        isLight ? Colors.white : const Color(0xFF06152A),
    surfaceContainerLow:
        isLight ? AppColors.surfaceMuted : const Color(0xFF102E50),
    surfaceContainer:
        isLight ? AppColors.surfaceMuted : const Color(0xFF14365C),
    surfaceContainerHigh:
        isLight ? AppColors.surfaceTint : const Color(0xFF1A426A),
    surfaceContainerHighest:
        isLight ? AppColors.primarySurfaceBorder : const Color(0xFF205078),
    error: AppColors.danger,
    onError: Colors.white,
    outline: isLight ? AppColors.primarySurfaceBorder : const Color(0xFF28618A),
    outlineVariant: isLight ? AppColors.primarySurface : const Color(0xFF17446A),
  );

  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  // Inter keeps headings and controls consistent with the compact POS design.
  TextTheme buildTextTheme(String displayFont, String bodyFont) {
    TextStyle display({
      required double size,
      required int weight,
      required Color color,
      double? height,
      double? letterSpacing,
    }) {
      return _textStyle(
        fontFamily: displayFont,
        size: size,
        weight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    TextStyle body({
      required double size,
      required int weight,
      required Color color,
      double? height,
      double? letterSpacing,
      bool tabular = false,
    }) {
      return _textStyle(
        fontFamily: bodyFont,
        size: size,
        weight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        tabular: tabular,
      );
    }

    return TextTheme(
      displayLarge: display(size: 42, weight: 700, color: onSurface, letterSpacing: -1.2, height: 1.08),
      displayMedium: display(size: 36, weight: 700, color: onSurface, letterSpacing: -0.8, height: 1.12),
      displaySmall: display(size: 30, weight: 700, color: onSurface, letterSpacing: -0.5, height: 1.18),
      headlineLarge: display(size: 26, weight: 700, color: onSurface, letterSpacing: -0.4, height: 1.22),
      headlineMedium: display(size: 22, weight: 600, color: onSurface, letterSpacing: -0.2, height: 1.26),
      headlineSmall: display(size: 19, weight: 600, color: onSurface, letterSpacing: -0.1, height: 1.3),
      titleLarge: body(size: 18, weight: 600, color: onSurface, height: 1.3, tabular: true),
      titleMedium: body(size: 16, weight: 600, color: onSurface, height: 1.35, tabular: true),
      titleSmall: body(size: 14, weight: 600, color: onSurface, height: 1.35, tabular: true),
      bodyLarge: body(size: 16, weight: 400, color: onSurface, height: 1.55, tabular: true),
      bodyMedium: body(size: 14, weight: 400, color: onSurfaceVariant, height: 1.5, tabular: true),
      bodySmall: body(size: 12, weight: 400, color: onSurfaceVariant, height: 1.45, tabular: true),
      labelLarge: body(size: 14, weight: 600, color: onSurface, letterSpacing: 0.1, height: 1.2, tabular: true),
      labelMedium: body(size: 12, weight: 600, color: onSurface, letterSpacing: 0.2, height: 1.2, tabular: true),
      labelSmall: body(size: 11, weight: 500, color: onSurfaceVariant, letterSpacing: 0.3, height: 1.2, tabular: true),
    );
  }

  final textTheme = buildTextTheme('Inter', 'Inter');

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface),
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
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      indicatorColor: isLight ? AppColors.primarySurface : Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
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
      labelStyle: textTheme.labelLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      contentTextStyle: TextStyle(color: scheme.surface, fontFamily: 'Inter'),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.surfaceMuted : scheme.surfaceContainerHighest,
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
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.18);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.focused)) {
            return Colors.white.withValues(alpha: 0.14);
          }
          return null;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.14);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.focused)) {
            return scheme.primary.withValues(alpha: 0.10);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5));
          }
          if (states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered)) {
            return BorderSide(color: scheme.primary, width: 1.4);
          }
          return BorderSide(color: scheme.outlineVariant);
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: textTheme.labelLarge,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.16);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isLight ? AppColors.surfaceMuted : scheme.surfaceContainer,
      selectedColor: AppColors.primarySurface,
      labelStyle: textTheme.bodySmall?.copyWith(color: onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 16,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isLight ? AppColors.cardSurface : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 12,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: onSurface,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.16);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.18);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.12);
          }
          return null;
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return 0.0;
          if (states.contains(WidgetState.hovered)) return 2.0;
          if (states.contains(WidgetState.pressed)) return 0.0;
          return 0.0;
        }),
      ),
    ),
  );
}