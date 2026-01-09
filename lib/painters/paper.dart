import 'dart:math';

import 'package:flutter/material.dart';

/// Custom painter for hand-drawn rectangle effect with subtle noisy borders
class HandDrawnRectanglePainter extends CustomPainter {
  final Color color;
  final double progress;
  final Gradient? gradient;
  final double cornerRadius; // Make this configurable

  HandDrawnRectanglePainter({
    required this.color,
    required this.progress,
    this.gradient,
    this.cornerRadius = 15.0, // Default value, but can be overridden
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 2.5;
    final padding = 5.0;
    final width = size.width - (padding * 2);
    final height = size.height - (padding * 2);
    final radius = cornerRadius;
    const segmentLength = 3.0;
    const noiseAmount = 0.4;

    final centerPath = Path();

    // Helper function to add noisy line segment
    void addNoisyLine(double x1, double y1, double x2, double y2, int seedOffset) {
      final random = Random((progress * 3).floor() + seedOffset);
      final dx = x2 - x1;
      final dy = y2 - y1;
      final distance = sqrt(dx * dx + dy * dy);
      final steps = (distance / segmentLength).ceil();

      centerPath.moveTo(x1, y1);

      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final baseX = x1 + dx * t;
        final baseY = y1 + dy * t;

        // Add random noise perpendicular to the line
        final noisePerp = (random.nextDouble() - 0.5) * 2 * noiseAmount;
        final noiseTangent = (random.nextDouble() - 0.5) * 2 * noiseAmount * 0.5;

        // Perpendicular offset
        final perpX = -dy / distance * noisePerp;
        final perpY = dx / distance * noisePerp;

        // Tangential offset
        final tangentX = dx / distance * noiseTangent;
        final tangentY = dy / distance * noiseTangent;

        centerPath.lineTo(baseX + perpX + tangentX, baseY + perpY + tangentY);
      }
    }

    // Calculate the center line of the border (middle of the stroke)
    final borderOffset = padding + strokeWidth / 2;
    final borderWidth = width - strokeWidth;
    final borderHeight = height - strokeWidth;

    // Top side
    addNoisyLine(
      borderOffset + radius,
      borderOffset,
      borderOffset + borderWidth - radius,
      borderOffset,
      0,
    );

    // Top-right corner
    final topRightX = borderOffset + borderWidth;
    final topRightY = borderOffset;
    centerPath.quadraticBezierTo(
      topRightX,
      topRightY,
      topRightX,
      topRightY + radius,
    );

    // Right side
    addNoisyLine(
      topRightX,
      borderOffset + radius,
      topRightX,
      borderOffset + borderHeight - radius,
      1,
    );

    // Bottom-right corner
    final bottomRightX = borderOffset + borderWidth;
    final bottomRightY = borderOffset + borderHeight;
    centerPath.quadraticBezierTo(
      bottomRightX,
      bottomRightY,
      bottomRightX - radius,
      bottomRightY,
    );

    // Bottom side
    addNoisyLine(
      borderOffset + borderWidth - radius,
      bottomRightY,
      borderOffset + radius,
      bottomRightY,
      2,
    );

    // Bottom-left corner
    final bottomLeftX = borderOffset;
    final bottomLeftY = borderOffset + borderHeight;
    centerPath.quadraticBezierTo(
      bottomLeftX,
      bottomLeftY,
      bottomLeftX,
      bottomLeftY - radius,
    );

    // Left side
    addNoisyLine(
      bottomLeftX,
      borderOffset + borderHeight - radius,
      bottomLeftX,
      borderOffset + radius,
      3,
    );

    // Top-left corner
    final topLeftX = borderOffset;
    final topLeftY = borderOffset;
    centerPath.quadraticBezierTo(
      topLeftX,
      topLeftY,
      topLeftX + radius,
      topLeftY,
    );

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (gradient != null) {
      paint.shader = gradient!.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    } else {
      paint.color = color;
    }

    canvas.drawPath(centerPath, paint);
  }

  @override
  bool shouldRepaint(HandDrawnRectanglePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.gradient != gradient || oldDelegate.cornerRadius != cornerRadius;
  }
}
