import 'package:flutter/material.dart';

/// Paints `bgtheme.png` behind the whole app.
///
/// Sits above the [Navigator] in `MaterialApp.router`'s `builder`, so a single
/// instance covers every route: the auth landing, all five tabs, pushed child
/// pages, and the router's error page. Applying the image inside a single
/// screen's Scaffold would not work, because each tab owns its own Scaffold and
/// would paint straight over it.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.image});

  final Widget child;

  /// Defaults to [assetPath]. Overridable because a widget test has no asset
  /// manifest, so a real [AssetImage] would fail to resolve under `flutter test`.
  final ImageProvider? image;

  static const String assetPath = 'assets/images/bgtheme.png';

  @override
  Widget build(BuildContext context) {
    return Stack(
      // The image and the Navigator both fill the screen; neither should be
      // allowed to size the Stack to itself.
      fit: StackFit.expand,
      children: [
        Image(
          image: image ?? const AssetImage(assetPath),
          fit: BoxFit.cover,
          // The artwork is decorative. If it ever fails to resolve, an empty
          // box is the right outcome -- a red error box, or worse an exception
          // that takes the app down with it, would be far more disruptive.
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
        child,
      ],
    );
  }
}
