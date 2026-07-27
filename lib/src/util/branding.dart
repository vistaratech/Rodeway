import 'package:flutter/material.dart';

/// Rodeway brand colors matching the client-approved logo
class RodewayBrand {
  // Individual letter colors (Google-style)
  static const Color red = Color(0xFFEA4335);    // R, w
  static const Color blue = Color(0xFF4285F4);   // o, a
  static const Color yellow = Color(0xFFFBBC05); // d, y
  static const Color green = Color(0xFF34A853);  // e

  // Primary app color (red from logo)
  static const Color primary = red;

  /// Letter-color mapping for "Rodeway"
  static const List<Color> letterColors = [
    red,    // R
    blue,   // o
    yellow, // d
    green,  // e
    red,    // w
    blue,   // a
    yellow, // y
  ];
}

/// A widget that renders "Rodeway" with each letter colored
/// to match the client-approved logo.
class RodewayLogoText extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final List<Shadow>? shadows;

  const RodewayLogoText({
    super.key,
    this.fontSize = 40.0,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = 2.0,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    const String text = 'Rodeway';

    return Text.rich(
      TextSpan(
        children: List.generate(text.length, (i) {
          return TextSpan(
            text: text[i],
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
              color: RodewayBrand.letterColors[i],
              shadows: shadows,
            ),
          );
        }),
      ),
    );
  }
}

/// Animated version of [RodewayLogoText] — each letter slides up,
/// fades in, and scales with a staggered delay for a premium reveal effect.
///
/// Requires an [AnimationController] that drives the entire animation.
/// Each letter is assigned a staggered interval within the controller's
/// 0.0–1.0 range so they appear one after another.
class AnimatedRodewayLogoText extends StatelessWidget {
  final AnimationController controller;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final List<Shadow>? shadows;

  const AnimatedRodewayLogoText({
    super.key,
    required this.controller,
    this.fontSize = 40.0,
    this.fontWeight = FontWeight.w900,
    this.letterSpacing = 2.0,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    const String text = 'Rodeway';
    const int count = 7; // text.length

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            // Stagger: each letter gets a slice of the animation timeline
            // Overlap letters slightly for a smooth wave feel
            final double start = i * 0.1;          // 0.0, 0.1, 0.2 ... 0.6
            final double end = (start + 0.4).clamp(0.0, 1.0); // each letter takes 0.4 of the timeline

            final double t = Interval(start, end, curve: Curves.easeOutBack)
                .transform(controller.value);
            final double opacity = Interval(start, (start + 0.25).clamp(0.0, 1.0), curve: Curves.easeIn)
                .transform(controller.value);

            // Slide up from 20px below
            final double offsetY = 20.0 * (1.0 - t);
            // Scale from 0.5 → 1.0
            final double scale = 0.5 + 0.5 * t;

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Text(
                    text[i],
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      letterSpacing: letterSpacing,
                      color: RodewayBrand.letterColors[i],
                      shadows: shadows,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
