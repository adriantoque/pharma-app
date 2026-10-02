import 'package:flutter/material.dart';

/// Brand colours used across the app.
abstract final class AppColors {
  static const Color teal = Color(0xFF00695C);
  static const Color tealSurface = Color(0xFFE0F2F1);
  static const Color tealSurfaceBorder = Color(0xFFB2DFDB);
}

ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Plain white background per tab. In dark mode the surface colour keeps
    // things readable, but the app is pinned to light anyway.
    scaffoldBackgroundColor:
        brightness == Brightness.light ? Colors.white : scheme.surface,
    appBarTheme: const AppBarTheme(
      // Transparent reads as the scaffold's white under it, so the bar never
      // punches a seam into the screen above a scrolled list.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // Defaults to 3, which smears a tinted scrim as soon as a list scrolls
      // under the bar.
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      // The one piece of chrome that must stay opaque. It sits directly on the
      // background, and a transparent bar left the destinations unreadable.
      backgroundColor: scheme.surface,
      // Left on, M3 tints this elevated surface with primary, which would put
      // a teal film over the bottom of the screen.
      surfaceTintColor: Colors.transparent,
      // Lifts the bar off the background now that it no longer relies on being
      // transparent for contrast.
      elevation: 3,
      indicatorColor: scheme.secondaryContainer,
      // Keeps all four labels visible at every size; the default hides them on
      // short viewports, which is how a destination ends up as an unlabelled
      // icon.
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    // SnackBars are raised over the shell's bottom bar. The M3 default is
    // already opaque, but pinning it here means a future theme change cannot
    // quietly make errors unreadable.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
    ),
    inputDecorationTheme: InputDecorationTheme(
      // Themed rather than hard-coded so the fields stay legible in dark mode.
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
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
    ),
  );
}
