import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:oauthclient/utils/paper/paper.dart';

/// Calculates hand-drawn jitter for rendering.
///
/// This function generates consistent jitter values based on a seed and
/// jitter amount, which can be applied to text in various contexts
/// (straight, curved, etc.).
///
/// Parameters:
///   - random: A Random instance for generating jitter values
///   - jitterAmount: The magnitude of perpendicular jitter
///   - angle: (Optional) The angle to apply jitter relative to. If provided,
///     jitter is rotated into the coordinate system defined by this angle.
///     If null, jitter is applied directly to x/y offsets.
///
/// Returns:
///   A TextJitter object containing the offset and rotation to apply.
Jitter calculateJitter(
  math.Random random,
  double jitterAmount, {
  double? angle,
}) {
  // Generate jitter components
  final noisePerp = (random.nextDouble() - 0.5) * 2 * jitterAmount;
  final noiseTangent = (random.nextDouble() - 0.5) * 2 * jitterAmount * 0.5;
  final rotationJitter = (random.nextDouble() - 0.5) * 2 * 0.05; // ±0.05 radians

  // If no angle is provided, apply jitter directly
  if (angle == null) {
    return Jitter(
      offset: Offset(noiseTangent, noisePerp),
      angle: rotationJitter,
    );
  }

  // If angle is provided, rotate jitter into the angled coordinate system
  // (for curved text scenarios)
  final jitterX = -math.sin(angle) * noisePerp + math.cos(angle) * noiseTangent;
  final jitterY = math.cos(angle) * noisePerp + math.sin(angle) * noiseTangent;

  return Jitter(
    offset: Offset(jitterX, jitterY),
    angle: rotationJitter,
  );
}

/// A Text widget that applies a handdrawn papery jitter effect.
class JitteredText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int seed;
  final double jitterAmount;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const JitteredText(
    this.text, {
    super.key,
    this.style,
    this.seed = 0,
    this.jitterAmount = 1.5,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure the text to get its size
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textAlign: textAlign,
          maxLines: maxLines,
          ellipsis: overflow == TextOverflow.ellipsis ? '...' : null,
        );

        final maxWidth = constraints.maxWidth;

        textPainter.layout(maxWidth: maxWidth);
        return CustomPaint(
          painter: JitteredTextPainter(
            text: text,
            style: style,
            seed: seed,
            jitterAmount: jitterAmount,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            maxWidth: constraints.maxWidth,
          ),
          size: Size(textPainter.width, textPainter.height),
        );
      },
    );
  }
}

/// Custom painter that renders jittered text character by character.
class JitteredTextPainter extends CustomPainter {
  final String text;
  final TextStyle? style;
  final int seed;
  final double jitterAmount;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final double maxWidth;

  JitteredTextPainter({
    required this.text,
    this.style,
    required this.seed,
    required this.jitterAmount,
    required this.textAlign,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.maxWidth = double.infinity,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: overflow == TextOverflow.ellipsis ? '...' : null,
    );
    textPainter.layout(maxWidth: maxWidth);

    double xOffset = 0;
    if (textAlign == TextAlign.center) {
      xOffset = (maxWidth - textPainter.width) / 2;
    } else if (textAlign == TextAlign.right) {
      xOffset = maxWidth - textPainter.width;
    }

    // Get the laid out text info to handle wrapping correctly
    final lines = splitTextIntoLines(
      text,
      maxWidth: maxWidth,
      style: style,
    );

    double yOffset = 0;
    int charIndex = 0;

    // Paint each character with jitter, respecting line breaks
    for (final line in lines) {
      // Skip empty lines
      if (line.isEmpty) {
        yOffset += getLineHeight(style);
        continue;
      }

      double xPos = xOffset;

      // Calculate x offset for text alignment
      if (textAlign == TextAlign.center) {
        final linePainter = TextPainter(
          text: TextSpan(text: line, style: style),
          textDirection: TextDirection.ltr,
        );
        linePainter.layout(maxWidth: maxWidth);
        xPos = (maxWidth - linePainter.width) / 2;
      } else if (textAlign == TextAlign.right) {
        final linePainter = TextPainter(
          text: TextSpan(text: line, style: style),
          textDirection: TextDirection.ltr,
        );
        linePainter.layout(maxWidth: maxWidth);
        xPos = maxWidth - linePainter.width;
      }

      double charXPos = xPos;

      // Get character metrics for this line (handles kerning properly)
      final charMetrics = getCharacterMetrics(line, style);

      for (int i = 0; i < charMetrics.length; i++) {
        final metric = charMetrics[i];
        final random = math.Random(seed + charIndex);
        final jitter = calculateJitter(random, jitterAmount);

        renderJitteredCharacter(
          canvas,
          charMetrics[i].char,
          Offset(charXPos, yOffset),
          0.0, // angle
          style,
          jitter,
        );

        charXPos += metric.width;
        charIndex++;
      }

      // Move to next line (get line height from style or use default)
      final lineHeight = style?.height ?? 1.2;
      final fontSize = style?.fontSize ?? 14;
      yOffset += lineHeight * fontSize;
    }
  }

  @override
  bool shouldRepaint(JitteredTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.seed != seed ||
        oldDelegate.jitterAmount != jitterAmount ||
        oldDelegate.style != style ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.maxLines != maxLines ||
        oldDelegate.overflow != overflow ||
        oldDelegate.maxWidth != maxWidth;
  }
}
