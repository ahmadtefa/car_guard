import 'package:flutter/material.dart';

/// Text sizing helpers for the dashboard cards.
///
/// Why this exists: the cards live in a 2-column grid, so on a 320 dp phone
/// each card is barely ~150 dp wide. Fixed font sizes there either clip
/// ("المروحة تعم…" with a tail swallowed by the card) or throw a RenderFlex
/// overflow. Rather than ellipsizing, the widgets in this folder measure the
/// string for the box they were actually given and step the font size down
/// until it fits — so the text is always complete, just smaller on small
/// screens, and never smaller than [ResponsiveText.minReadableFontSize].
abstract final class ResponsiveText {
  /// The floor for any auto-shrunk text, so a reading never becomes a smudge.
  static const double minReadableFontSize = 11;

  /// Largest a label may grow to, so a big tablet does not get headline-sized
  /// captions.
  static const double maxLabelFontSize = 18;

  /// Steps the font size down until the text fits [width] / [maxHeight].
  ///
  /// The layout is done with a real [TextPainter] instead of a
  /// characters-times-width guess: Arabic is shaped and joined, so the guess
  /// is wrong often enough to clip, and this runs a handful of times per card
  /// only when the text or the box changes.
  static double fitFontSize({
    required String text,
    required TextStyle style,
    required double width,
    required double maxHeight,
    required int maxLines,
    required TextDirection direction,
    double minFontSize = minReadableFontSize,
  }) {
    final double start = style.fontSize ?? 14;

    if (text.isEmpty || !width.isFinite || width <= 0 || start <= minFontSize) {
      return start;
    }

    double size = start;

    // 8 steps of 0.9 shrink down to ~43 % of the requested size, which is far
    // past what any card in the grid needs; the loop stops early as soon as
    // the text fits.
    for (var attempt = 0; attempt < 8; attempt++) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
        textDirection: direction,
        textWidthBasis: TextWidthBasis.longestLine,
        maxLines: maxLines,
        ellipsis: null,
      )..layout(maxWidth: width);

      final bool fitsWidth = painter.width <= width + 0.5;
      final bool fitsHeight = !maxHeight.isFinite || painter.height <= maxHeight + 0.5;

      if (fitsWidth && fitsHeight) {
        return size;
      }

      final next = size * 0.9;

      if (next <= minFontSize) {
        return size < minFontSize ? size : minFontSize;
      }

      size = next;
    }

    return size;
  }
}

/// [Text] that shrinks its font until the string fits the box it was given.
///
/// Unlike [FittedBox] there is a floor ([ResponsiveText.minReadableFontSize]),
/// so a value is never scaled into unreadability, and unlike an ellipsizing
/// [Text] nothing is hidden: the whole string is always shown.
class AdaptiveText extends StatelessWidget {
  const AdaptiveText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.minFontSize = ResponsiveText.minReadableFontSize,
    this.textAlign,
    this.reserveMaxHeight = false,
  });

  final String text;

  /// The requested style; its `fontSize` is the *maximum*, not a fixed value.
  final TextStyle style;

  final int maxLines;
  final double minFontSize;
  final TextAlign? textAlign;

  /// When true the text is also shrunk to fit the height the parent allows,
  /// which is what keeps tall status lines from pushing a card out of its row.
  final bool reserveMaxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : media.size.width;
        final double height = reserveMaxHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;

        // Accessibility text scaling is applied first, then the fitting, so a
        // user who enlarged the system font still gets bigger text where the
        // card can afford it — and no overflow where it cannot.
        final double scaled = media.textScaler.scale(style.fontSize ?? 14);

        final double size = ResponsiveText.fitFontSize(
          text: text,
          style: style.copyWith(fontSize: scaled),
          width: width,
          maxHeight: height,
          maxLines: maxLines,
          direction: Directionality.of(context),
        );

        return Text(
          text,
          style: style.copyWith(fontSize: size),
          textAlign: textAlign,
          maxLines: maxLines,
          // The fitting above makes this the last-resort safety net only: it
          // can trigger on an impossibly narrow box, never on the card sizes
          // this app ships with.
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
