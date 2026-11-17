import 'package:flutter/material.dart';

/// Shared, overflow-safe layout helpers.
///
/// These keep the visual design intact while preventing RenderFlex overflows
/// on narrow widths: content is allowed to shrink/wrap instead of forcing a
/// fixed pixel size.

/// A horizontal group that wraps instead of overflowing.
class FlexibleButtonRow extends StatelessWidget {
  const FlexibleButtonRow({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
    this.alignment = WrapAlignment.start,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Text that cannot push a row past its bounds.
class EllipsisText extends StatelessWidget {
  const EllipsisText(
    this.data, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  final String data;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      textAlign: textAlign,
    );
  }
}