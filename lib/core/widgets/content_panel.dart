import 'package:flutter/material.dart';

/// Puts a tab's content on a raised surface so it stays readable over
/// [AppBackground]'s artwork.
///
/// The illustration is light (roughly 88% luminance), so dark body text and
/// outlined controls sitting directly on it lose contrast. Rather than dimming
/// or removing the artwork, each tab's content gets its own card and the image
/// stays visible in the margin around it.
///
/// Mounted once by `AppShell` around the whole navigation shell, so every tab
/// and every pushed child page inherits it.
class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key, required this.child, this.margin});

  final Widget child;

  /// Leaves a strip of artwork visible around the panel. Defaults to a slightly
  /// larger gap at the top, where the image's illustration sits.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(12, 14, 12, 10),
      // The child holds each tab's own Scaffold, whose background is
      // transparent so this surface shows through. Clipping rounds the tab's
      // scrollable content to the panel's corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Near-opaque rather than solid: dark body text on this composited
        // surface still clears 10:1 contrast against the artwork behind it,
        // while a trace of the illustration still shows through.
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
