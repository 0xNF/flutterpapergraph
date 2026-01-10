import 'dart:math' as math;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/utils/bezier/bezier.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class ConnectionsPainter extends CustomPainter {
  final ControlFlowGraph graph;
  final Map<String, Offset> nodeScreenPositions;
  final GraphFlowController controller;
  final Size containerSize;
  final bool usePaper;
  final PaperSettings? paperSettings;
  final EdgeSettings edgeSettings;
  final double drawingProgress;
  final Map<String, int> connectionSeeds;

  static const double controlPointHorizontalOffset = 80;

  ConnectionsPainter({
    required this.graph,
    required this.nodeScreenPositions,
    required this.controller,
    required this.containerSize,
    required this.edgeSettings,
    this.usePaper = true,
    this.paperSettings,
    this.drawingProgress = 0.0,
    required this.connectionSeeds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = edgeSettings.idleColor
      ..strokeWidth = edgeSettings.strokeWidth
      ..style = PaintingStyle.stroke;

    for (final connection in graph.connections) {
      final fromNode = graph.getNode(connection.fromId);
      final toNode = graph.getNode(connection.toId);

      if (fromNode == null || toNode == null) continue;

      final fromPos = nodeScreenPositions[fromNode.id];
      final toPos = nodeScreenPositions[toNode.id];

      if (fromPos == null || toPos == null) continue;

      final seed = connectionSeeds[connection.connectionId] ?? 0; // ← Get this connection's seed

      _drawConnection(canvas, fromPos, toPos, connection.curveBend, paint, seed, paperSettings, connection.connectionState);
      _drawArrowHead(canvas, fromPos, toPos, paint, connection.arrowPositionAlongCurve, connection.curveBend, seed, paperSettings, connection.connectionState);
    }
  }

  void _drawConnection2(Canvas canvas, Offset fromPos, Offset toPos, double curveBend, Paint paint, int seed, PaperSettings? paperSettings, ConnectionState connectionState) {
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
      _drawHandDrawnPath(canvas, path, paint, seed, paperSettings!, connectionState);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawConnection(Canvas canvas, Offset fromPos, Offset toPos, double curveBend, Paint paint, int seed, PaperSettings? paperSettings, ConnectionState connectionState) {
    final (cp1, cp2) = BezierUtils.calculateControlPoints(
      fromPos,
      toPos,
      controlPointHorizontalOffset,
      curveBend,
    );

    final fullPath = Path()
      ..moveTo(fromPos.dx, fromPos.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, toPos.dx, toPos.dy);

    // Draw colored segments
    _drawColoredSegments(canvas, fullPath, paint, seed, paperSettings, connectionState);
  }

  void _drawColoredSegments(Canvas canvas, Path path, Paint basePaint, int seed, PaperSettings? paperSettings, ConnectionState connectionState) {
    final pathMetrics = path.computeMetrics();

    final color = switch (connectionState) {
      ConnectionState.idle => edgeSettings.arrowSettings.color,
      ConnectionState.inProgress => edgeSettings.arrowSettings.color,
      ConnectionState.error => edgeSettings.errorColor,
      ConnectionState.disabled => edgeSettings.disabledColor,
    };

    for (final pathMetric in pathMetrics) {
      final totalLength = pathMetric.length;
      const numSegments = 3;
      final segmentLength = totalLength / numSegments;

      for (int i = 0; i < numSegments; i++) {
        final startDist = i * segmentLength;
        final endDist = (i + 1) * segmentLength;

        // Build segment path
        final segmentPath = Path();
        final startTangent = pathMetric.getTangentForOffset(startDist);

        if (startTangent == null) continue;

        segmentPath.moveTo(startTangent.position.dx, startTangent.position.dy);

        // Sample points along the segment
        const samplesPerSegment = 20;
        for (int j = 1; j <= samplesPerSegment; j++) {
          final distance = startDist + (j / samplesPerSegment) * (endDist - startDist);
          final tangent = pathMetric.getTangentForOffset(distance);

          if (tangent != null) {
            segmentPath.lineTo(tangent.position.dx, tangent.position.dy);
          }
        }

        // Create paint for this segment with a different color
        final segmentPaint = Paint()
          ..color = color
          ..strokeWidth = basePaint.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        // Draw the segment
        if (usePaper) {
          // Apply hand-drawn effect if using paper
          // You might want to create a separate method for this
          _drawHandDrawnPath(canvas, segmentPath, segmentPaint, seed, paperSettings!, connectionState);
        } else {
          canvas.drawPath(segmentPath, segmentPaint);
        }
      }
    }
  }

  Color _getColorForSegment(int segmentIndex, ConnectionState connectionState) {
    final colors = [Colors.blue, Colors.green, Colors.red];

    if (connectionState == ConnectionState.error) {
      return edgeSettings.errorColor;
    } else if (connectionState == ConnectionState.disabled) {
      return edgeSettings.disabledColor;
    }

    return colors[segmentIndex % colors.length];
  }

  void _drawHandDrawnPath(Canvas canvas, Path originalPath, Paint paint, int seed, PaperSettings edgeSettings, ConnectionState connectionState) {
    // Convert path to a list of points for hand-drawn effect

    final pathMetrics = originalPath.computeMetrics();
    final handDrawnPath = Path();
    bool isFirstSegment = true;

    for (final pathMetric in pathMetrics) {
      final totalLength = pathMetric.length;
      final random = math.Random(connectionState == ConnectionState.disabled ? 0 : seed); // Changes 9x per cycle
      final steps = (totalLength / edgeSettings.edgeSettings.segmentlength).ceil();

      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final distance = t * totalLength;
        final tangent = pathMetric.getTangentForOffset(distance);

        if (tangent == null) continue;

        final baseOffset = tangent.position;

        // Add random noise perpendicular to the tangent
        final noisePerp = (random.nextDouble() - 0.5) * 2 * edgeSettings.edgeSettings.noiseAmount;
        final noiseTangent = (random.nextDouble() - 0.5) * 2 * edgeSettings.edgeSettings.noiseAmount * 0.5;

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

  void _drawArrowHead(Canvas canvas, Offset fromPos, Offset toPos, Paint paint, double arrowPositionAlongCurve, double curveBend, int seed, PaperSettings? paperSettings, ConnectionState connectionState) {
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

    final color = switch (connectionState) {
      ConnectionState.idle => edgeSettings.arrowSettings.color,
      ConnectionState.inProgress => edgeSettings.arrowSettings.color,
      ConnectionState.error => edgeSettings.errorColor,
      ConnectionState.disabled => edgeSettings.disabledColor,
    };

    final arrowPaint = Paint()
      ..color = color
      ..style = edgeSettings.arrowSettings.paintingStyle;

    if (usePaper) {
      // Hand-drawn arrow with variable edge lengths
      final random = math.Random(connectionState == ConnectionState.disabled ? 0 : seed);

      // Jitter the arrow origin point
      final jitteredArrowPos = Offset(
        arrowPos.dx + (random.nextDouble() - 0.5) * 2 * paperSettings!.arrowSettings.originJitter,
        arrowPos.dy + (random.nextDouble() - 0.5) * 2 * paperSettings.arrowSettings.originJitter,
      );

      // Vary the arrow size for each edge
      final leftSize = edgeSettings.arrowSettings.size * (1 + (random.nextDouble() - 0.5) * 2 * paperSettings.arrowSettings.sizeVariationAsPercent);
      final rightSize = edgeSettings.arrowSettings.size * (1 + (random.nextDouble() - 0.5) * 2 * paperSettings.arrowSettings.sizeVariationAsPercent);

      final left = Offset(
        jitteredArrowPos.dx - leftSize * math.cos(angle - edgeSettings.arrowSettings.angle),
        jitteredArrowPos.dy - leftSize * math.sin(angle - edgeSettings.arrowSettings.angle),
      );

      final right = Offset(
        jitteredArrowPos.dx - rightSize * math.cos(angle + edgeSettings.arrowSettings.angle),
        jitteredArrowPos.dy - rightSize * math.sin(angle + edgeSettings.arrowSettings.angle),
      );

      final outlinePaint = Paint()
        ..color = color
        ..strokeWidth = edgeSettings.arrowSettings.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Draw three noisy edges with varied lengths: tip to left, left to right, right to tip
      _drawNoisyLine(canvas, jitteredArrowPos, left, outlinePaint, random, paperSettings.arrowSettings.segmentLength, paperSettings.arrowSettings.startJitter, paperSettings.arrowSettings.noiseAmount);
      _drawNoisyLine(canvas, left, right, outlinePaint, random, paperSettings.arrowSettings.segmentLength, paperSettings.arrowSettings.startJitter, paperSettings.arrowSettings.noiseAmount);
      _drawNoisyLine(canvas, right, jitteredArrowPos, outlinePaint, random, paperSettings.arrowSettings.segmentLength, paperSettings.arrowSettings.startJitter, paperSettings.arrowSettings.noiseAmount);

      // Fill the arrow with solid color
      final arrowPath = Path()
        ..moveTo(jitteredArrowPos.dx, jitteredArrowPos.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();

      canvas.drawPath(arrowPath, arrowPaint..style = edgeSettings.arrowSettings.paintingStyle);
    } else {
      // Original arrow - consistent size
      final left = Offset(
        arrowPos.dx - edgeSettings.arrowSettings.size * math.cos(angle - edgeSettings.arrowSettings.angle),
        arrowPos.dy - edgeSettings.arrowSettings.size * math.sin(angle - edgeSettings.arrowSettings.angle),
      );

      final right = Offset(
        arrowPos.dx - edgeSettings.arrowSettings.size * math.cos(angle + edgeSettings.arrowSettings.angle),
        arrowPos.dy - edgeSettings.arrowSettings.size * math.sin(angle + edgeSettings.arrowSettings.angle),
      );

      final arrowPath = Path()
        ..moveTo(arrowPos.dx, arrowPos.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();

      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  void _drawNoisyLine(Canvas canvas, Offset start, Offset end, Paint paint, math.Random random, double segmentLength, double startJitter, double noiseAmount) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance == 0) return;

    final steps = (distance / segmentLength).ceil();
    final path = Path();

    // Add jitter to the starting point itself
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
