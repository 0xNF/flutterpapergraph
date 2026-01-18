// new file: text_layout_utils.dart
import 'package:flutter/material.dart';

class CharacterMetric {
  final double xStart;
  final double xEnd;
  final String char;

  CharacterMetric({
    required this.xStart,
    required this.xEnd,
    required this.char,
  });

  double get width => xEnd - xStart;
  double get centerX => xStart + (width / 2);
}

List<CharacterMetric> getCharacterMetrics(
  String text,
  TextStyle? style,
) {
  final textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();

  final metrics = <CharacterMetric>[];

  for (int i = 0; i < text.length; i++) {
    final startOffset = textPainter
        .getOffsetForCaret(
          TextPosition(offset: i),
          Rect.zero,
        )
        .dx;

    final endOffset = textPainter
        .getOffsetForCaret(
          TextPosition(offset: i + 1),
          Rect.zero,
        )
        .dx;

    metrics.add(
      CharacterMetric(
        xStart: startOffset,
        xEnd: endOffset,
        char: text[i],
      ),
    );
  }

  return metrics;
}

// new file: text_utils.dart
List<String> splitTextIntoLines(
  String text, {
  double maxWidth = double.infinity,
  TextStyle? style,
}) {
  if (maxWidth == double.infinity || !text.contains('\n')) {
    return text.split('\n');
  }

  final lines = <String>[];
  var currentLine = '';

  for (final char in text.characters) {
    currentLine += char;
    final linePainter = TextPainter(
      text: TextSpan(text: currentLine, style: style),
      textDirection: TextDirection.ltr,
    );
    linePainter.layout(maxWidth: maxWidth);

    if (char == '\n' || linePainter.didExceedMaxLines || linePainter.width > maxWidth) {
      lines.add(currentLine.substring(0, currentLine.length - 1));
      currentLine = char;
    }
  }

  if (currentLine.isNotEmpty) {
    lines.add(currentLine);
  }

  return lines;
}

void renderJitteredCharacter(
  Canvas canvas,
  String char,
  Offset position,
  double angle,
  TextStyle? style,
  Jitter? jitter,
) {
  final charPainter = TextPainter(
    text: TextSpan(text: char, style: style),
    textDirection: TextDirection.ltr,
  );
  charPainter.layout();

  canvas.save();

  // Translate to character position with optional jitter
  canvas.translate(
    position.dx + (jitter?.offset.dx ?? 0),
    position.dy + (jitter?.offset.dy ?? 0),
  );

  // Apply rotation around character center
  canvas.translate(charPainter.width / 2, charPainter.height / 2);
  canvas.rotate(angle + (jitter?.angle ?? 0));
  canvas.translate(-charPainter.width / 2, -charPainter.height / 2);

  charPainter.paint(canvas, Offset.zero);

  canvas.restore();
}

/// Represents the jitter applied to a character
class Jitter {
  /// Offset to apply to the character position (in the local coordinate system)
  final Offset offset;

  /// Rotation angle to apply (in radians)
  final double angle;

  Jitter({
    required this.offset,
    required this.angle,
  });
}

double getLineHeight(TextStyle? style, {double defaultFontSize = 14}) {
  final lineHeight = style?.height ?? 1.2;
  final fontSize = style?.fontSize ?? defaultFontSize;
  return lineHeight * fontSize;
}
