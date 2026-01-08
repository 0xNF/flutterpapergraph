import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/utils/bezier/bezier.dart';

class ConnectionsPainter extends CustomPainter {
  final ControlFlowGraph graph;
  final Map<String, Offset> nodeScreenPositions;
  final GraphFlowController controller;
  final Size containerSize;
  final bool usePaper;
  final double drawingProgress;
  final Map<String, int> connectionSeeds;
  static const double controlPointHorizontalOffset = 80;
  static const double connectionStrokeWidth = 2.5;
  static const int connectionColor = 0xFF64B5F6;
  static const double arrowSize = 24;
  static const double arrowAngle = math.pi / 6; // 30 degrees

  ConnectionsPainter({
    required this.graph,
    required this.nodeScreenPositions,
    required this.controller,
    required this.containerSize,
    this.usePaper = true,
    this.drawingProgress = 0.0,
    required this.connectionSeeds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(connectionColor)
      ..strokeWidth = connectionStrokeWidth
      ..style = PaintingStyle.stroke;

    for (final connection in graph.connections) {
      final fromNode = graph.getNode(connection.fromId);
      final toNode = graph.getNode(connection.toId);

      if (fromNode == null || toNode == null) continue;

      final fromPos = nodeScreenPositions[fromNode.id];
      final toPos = nodeScreenPositions[toNode.id];

      if (fromPos == null || toPos == null) continue;

      final connectionId = '${connection.fromId}-${connection.toId}';
      final seed = connectionSeeds[connectionId] ?? 0; // ← Get this connection's seed

      _drawConnection(canvas, fromPos, toPos, connection.curveBend, paint, seed);
      _drawArrowHead(canvas, fromPos, toPos, paint, connection.arrowPositionAlongCurve, connection.curveBend, seed);
    }
  }

  void _drawConnection(Canvas canvas, Offset fromPos, Offset toPos, double curveBend, Paint paint, int seed) {
    final (cp1, cp2) = BezierUtils.calculateControlPoints(
      fromPos,
      toPos,
      controlPointHorizontalOffset,
      curveBend,
    );

    final path = Path()
      ..moveTo(fromPos.dx, fromPos.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, toPos.dx, toPos.dy);

    if (usePaper) {
      _drawHandDrawnPath(canvas, path, paint, seed);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawHandDrawnPath(Canvas canvas, Path originalPath, Paint paint, int seed) {
    // Convert path to a list of points for hand-drawn effect
    const segmentLength = 3.0;
    const noiseAmount = 0.3;

    final pathMetrics = originalPath.computeMetrics();
    final handDrawnPath = Path();
    bool isFirstSegment = true;

    for (final pathMetric in pathMetrics) {
      final totalLength = pathMetric.length;
      final random = math.Random(seed); // Changes 9x per cycle
      final steps = (totalLength / segmentLength).ceil();

      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final distance = t * totalLength;
        final tangent = pathMetric.getTangentForOffset(distance);

        if (tangent == null) continue;

        final baseOffset = tangent.position;

        // Add random noise perpendicular to the tangent
        final noisePerp = (random.nextDouble() - 0.5) * 2 * noiseAmount;
        final noiseTangent = (random.nextDouble() - 0.5) * 2 * noiseAmount * 0.5;

        // Perpendicular direction
        final angle = tangent.angle;
        final perpX = -math.sin(angle) * noisePerp;
        final perpY = math.cos(angle) * noisePerp;

        // Tangential direction
        final tangentX = math.cos(angle) * noiseTangent;
        final tangentY = math.sin(angle) * noiseTangent;

        final noisyOffset = Offset(
          baseOffset.dx + perpX + tangentX,
          baseOffset.dy + perpY + tangentY,
        );

        if (isFirstSegment) {
          handDrawnPath.moveTo(noisyOffset.dx, noisyOffset.dy);
          isFirstSegment = false;
        } else {
          handDrawnPath.lineTo(noisyOffset.dx, noisyOffset.dy);
        }
      }
    }

    canvas.drawPath(handDrawnPath, paint);
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset fromPos,
    Offset toPos,
    Paint paint,
    double arrowPositionAlongCurve,
    double curveBend,
    int seed,
  ) {
    final (cp1, cp2) = BezierUtils.calculateControlPoints(
      fromPos,
      toPos,
      controlPointHorizontalOffset,
      curveBend,
    );

    // Get position and tangent at the specified point along the curve
    final arrowPos = BezierUtils.evaluateCubicBezier(
      fromPos,
      cp1,
      cp2,
      toPos,
      arrowPositionAlongCurve,
    );

    final tangent = BezierUtils.evaluateCubicBezierTangent(
      fromPos,
      cp1,
      cp2,
      toPos,
      arrowPositionAlongCurve,
    );

    // Normalize the tangent vector
    final tangentLength = math.sqrt(tangent.dx * tangent.dx + tangent.dy * tangent.dy);
    if (tangentLength == 0) return;

    final normalizedTangent = Offset(tangent.dx / tangentLength, tangent.dy / tangentLength);
    final angle = math.atan2(normalizedTangent.dy, normalizedTangent.dx);

    final arrowPaint = Paint()
      ..color = Color(connectionColor)
      ..style = PaintingStyle.fill;

    if (usePaper) {
      // Hand-drawn arrow with variable edge lengths
      final random = math.Random(seed);
      const segmentLength = 2.0;
      const noiseAmount = 0.4;
      const sizeVariation = 0.15; // 15% variation in arrow size
      const originJitter = 1.5; // Jitter amount for arrow origin

      // Jitter the arrow origin point
      final jitteredArrowPos = Offset(
        arrowPos.dx + (random.nextDouble() - 0.5) * 2 * originJitter,
        arrowPos.dy + (random.nextDouble() - 0.5) * 2 * originJitter,
      );

      // Vary the arrow size for each edge
      final leftSize = arrowSize * (1 + (random.nextDouble() - 0.5) * 2 * sizeVariation);
      final rightSize = arrowSize * (1 + (random.nextDouble() - 0.5) * 2 * sizeVariation);

      final left = Offset(
        jitteredArrowPos.dx - leftSize * math.cos(angle - arrowAngle),
        jitteredArrowPos.dy - leftSize * math.sin(angle - arrowAngle),
      );

      final right = Offset(
        jitteredArrowPos.dx - rightSize * math.cos(angle + arrowAngle),
        jitteredArrowPos.dy - rightSize * math.sin(angle + arrowAngle),
      );

      final outlinePaint = Paint()
        ..color = Color(connectionColor)
        ..strokeWidth = connectionStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Draw three noisy edges with varied lengths: tip to left, left to right, right to tip
      _drawNoisyLine(canvas, jitteredArrowPos, left, outlinePaint, random, segmentLength, noiseAmount);
      _drawNoisyLine(canvas, left, right, outlinePaint, random, segmentLength, noiseAmount);
      _drawNoisyLine(canvas, right, jitteredArrowPos, outlinePaint, random, segmentLength, noiseAmount);

      // Fill the arrow with solid color
      final arrowPath = Path()
        ..moveTo(jitteredArrowPos.dx, jitteredArrowPos.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();

      canvas.drawPath(arrowPath, arrowPaint..style = PaintingStyle.fill);
    } else {
      // Original arrow - consistent size
      final left = Offset(
        arrowPos.dx - arrowSize * math.cos(angle - arrowAngle),
        arrowPos.dy - arrowSize * math.sin(angle - arrowAngle),
      );

      final right = Offset(
        arrowPos.dx - arrowSize * math.cos(angle + arrowAngle),
        arrowPos.dy - arrowSize * math.sin(angle + arrowAngle),
      );

      final arrowPath = Path()
        ..moveTo(arrowPos.dx, arrowPos.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  void _drawNoisyLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    math.Random random,
    double segmentLength,
    double noiseAmount,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance == 0) return;

    final steps = (distance / segmentLength).ceil();
    final path = Path();

    // Add jitter to the starting point itself
    const startJitter = 0.8;
    final jitteredStartX = start.dx + (random.nextDouble() - 0.5) * 2 * startJitter;
    final jitteredStartY = start.dy + (random.nextDouble() - 0.5) * 2 * startJitter;
    path.moveTo(jitteredStartX, jitteredStartY);
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final baseX = start.dx + dx * t;
      final baseY = start.dy + dy * t;

      // Add random noise perpendicular to the line
      final noisePerp = (random.nextDouble() - 0.5) * 2 * noiseAmount;
      final noiseTangent = (random.nextDouble() - 0.5) * 2 * noiseAmount * 0.5;

      // Perpendicular offset
      final perpX = -dy / distance * noisePerp;
      final perpY = dx / distance * noisePerp;

      // Tangential offset
      final tangentX = dx / distance * noiseTangent;
      final tangentY = dy / distance * noiseTangent;

      path.lineTo(baseX + perpX + tangentX, baseY + perpY + tangentY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ConnectionsPainter oldDelegate) {
    return oldDelegate.nodeScreenPositions != nodeScreenPositions || oldDelegate.graph.connections.length != graph.connections.length || oldDelegate.usePaper != usePaper || oldDelegate.drawingProgress != drawingProgress;
  }
}
