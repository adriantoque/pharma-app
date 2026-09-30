import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown while Firebase initialises, before the real app is built.
///
/// Renders the same `bgtheme.png` the Android launch background uses, so the
/// handoff from the native window to the first Flutter frame is invisible
/// rather than a jump. [BoxFit.cover] and the launch background's `fill` agree
/// exactly on a screen whose aspect matches the image's.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.imagePath = 'assets/images/bgtheme.png'});

  /// Overridable because a widget test has no asset manifest.
  final String imagePath;

  /// Brand name, matching the auth landing screen. The asset is shared with
  /// Android's launch background as a res/ copy, since a layer-list cannot
  /// reach the Flutter asset bundle.
  static const String _title = "Wilma\nPharmacy's";

  @override
  Widget build(BuildContext context) {
    final theme = buildAppTheme(Brightness.light);

    // Its own MaterialApp: this is the root of the tree while the bootstrap
    // future is pending, so there is no inherited theme, Directionality or
    // MediaQuery to draw on.
    return MaterialApp(
      title: 'PharmaGuide',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        // Opaque for the same reason the login screen is: the theme's
        // scaffold background is transparent.
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: const AssetImage(
                      'assets/images/baseIcon.png',
                    ),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 40,
                      color: AppColors.teal,
                      fontFamily: 'PlayfairDisplay',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.teal.withValues(alpha: 0.7),
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
