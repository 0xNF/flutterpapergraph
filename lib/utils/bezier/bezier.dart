// ============================================================================
// BEZIER UTILITIES
// ============================================================================

import 'dart:ui';

class BezierUtils {
  /// Evaluate a cubic bezier curve at parameter t (0.0 to 1.0)
  static Offset evaluateCubicBezier(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final mt = 1 - t;
    final mt2 = mt * mt;
    final t2 = t * t;

    return Offset(
      mt2 * mt * p0.dx + 3 * mt2 * t * p1.dx + 3 * mt * t2 * p2.dx + t2 * t * p3.dx,
      mt2 * mt * p0.dy + 3 * mt2 * t * p1.dy + 3 * mt * t2 * p2.dy + t2 * t * p3.dy,
    );
  }

  /// Get tangent (derivative) of cubic bezier at parameter t
  static Offset evaluateCubicBezierTangent(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
  ) {
    final mt = 1 - t;
    final mt2 = mt * mt;
    final t2 = t * t;

    return Offset(
      3 * mt2 * (p1.dx - p0.dx) + 6 * mt * t * (p2.dx - p1.dx) + 3 * t2 * (p3.dx - p2.dx),
      3 * mt2 * (p1.dy - p0.dy) + 6 * mt * t * (p2.dy - p1.dy) + 3 * t2 * (p3.dy - p2.dy),
    );
  }

  static (Offset, Offset) calculateControlPoints(
    Offset start,
    Offset end,
    double horizontalOffset,
    double bend,
  ) {
    final midpoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    // Apply vertical bend at centerpoint
    final bentMidpoint = Offset(
      midpoint.dx,
      midpoint.dy + bend, // Positive = down, negative = up
    );

    // Calculate control points from start to bent midpoint and midpoint to end
    final cp1 = Offset(
      start.dx + horizontalOffset,
      start.dy + (bentMidpoint.dy - start.dy) / 2,
    );

    final cp2 = Offset(
      end.dx - horizontalOffset,
      end.dy + (bentMidpoint.dy - end.dy) / 2,
    );

    return (cp1, cp2);
  }
}
