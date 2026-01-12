import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Represents the jitter applied to a character
class TextJitter {
  /// Offset to apply to the character position (in the local coordinate system)
  final Offset offset;

  /// Rotation angle to apply (in radians)
  final double angle;

  TextJitter({
    required this.offset,
    required this.angle,
  });
}

/// Calculates hand-drawn jitter for text rendering.
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
TextJitter calculateTextJitter(
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
    return TextJitter(
      offset: Offset(noiseTangent, noisePerp),
      angle: rotationJitter,
    );
  }

  // If angle is provided, rotate jitter into the angled coordinate system
  // (for curved text scenarios)
  final jitterX = -math.sin(angle) * noisePerp + math.cos(angle) * noiseTangent;
  final jitterY = math.cos(angle) * noisePerp + math.sin(angle) * noiseTangent;

  return TextJitter(
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

  const JitteredText(
    this.text, {
    super.key,
    this.style,
    this.seed = 0,
    this.jitterAmount = 1.5,
    this.textAlign = TextAlign.left,
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
        );
        textPainter.layout();

        return CustomPaint(
          painter: JitteredTextPainter(
            text: text,
            style: style,
            seed: seed,
            jitterAmount: jitterAmount,
            textAlign: textAlign,
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

  JitteredTextPainter({
    required this.text,
    this.style,
    required this.seed,
    required this.jitterAmount,
    required this.textAlign,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );
    textPainter.layout(maxWidth: size.width);

    double xOffset = 0;
    if (textAlign == TextAlign.center) {
      xOffset = (size.width - textPainter.width) / 2;
    } else if (textAlign == TextAlign.right) {
      xOffset = size.width - textPainter.width;
    }

    // Paint each character with jitter
    for (int i = 0; i < text.length; i++) {
      final random = math.Random(seed + i);
      final jitter = calculateTextJitter(random, jitterAmount);

      // Get character position
      final charOffset = _getCharacterOffset(i);

      // Create character painter
      final charPainter = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      );
      charPainter.layout();

      canvas.save();

      // Translate to character position with jitter
      canvas.translate(
        xOffset + charOffset.dx + jitter.offset.dx,
        charOffset.dy + jitter.offset.dy,
      );

      // Apply rotation around character center
      canvas.translate(charPainter.width / 2, charPainter.height / 2);
      canvas.rotate(jitter.angle);
      canvas.translate(-charPainter.width / 2, -charPainter.height / 2);

      charPainter.paint(canvas, Offset.zero);

      canvas.restore();
    }
  }

  /// Calculate the x offset of a character by measuring text up to that character.
  Offset _getCharacterOffset(int charIndex) {
    final beforeText = TextPainter(
      text: TextSpan(text: text.substring(0, charIndex), style: style),
      textDirection: TextDirection.ltr,
    );
    beforeText.layout();

    return Offset(beforeText.width, 0);
  }

  @override
  bool shouldRepaint(JitteredTextPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.seed != seed || oldDelegate.jitterAmount != jitterAmount || oldDelegate.style != style || oldDelegate.textAlign != textAlign;
  }
}
