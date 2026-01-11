// animated_edge_label_widget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/animated_label.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/painters/paper.dart';
import 'package:oauthclient/utils/bezier/bezier.dart';
import 'package:oauthclient/painters/edgespainter.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class AnimatedEdgeLabelWidget extends StatefulWidget {
  final AnimatedLabel label;
  final GraphEdgeData edgeData;
  final ControlFlowGraph graph;
  final Map<String, Offset> nodeScreenPositions;
  final GraphFlowController controller;
  final bool usePaper;
  final PaperSettings? paperSettings;

  const AnimatedEdgeLabelWidget({
    super.key,
    required this.label,
    required this.edgeData,
    required this.graph,
    required this.nodeScreenPositions,
    required this.controller,
    required this.usePaper,
    this.paperSettings,
  });

  @override
  State<AnimatedEdgeLabelWidget> createState() => _AnimatedEdgeLabelWidgetState();
}

class _AnimatedEdgeLabelWidgetState extends State<AnimatedEdgeLabelWidget> with TickerProviderStateMixin {
  late AnimationController _drawingController;

  @override
  void initState() {
    // Drawing animation controller - only needed for paper style
    _drawingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (widget.usePaper) {
      _drawingController.repeat();
    }

    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeAnimatingLabel(widget.label.id, notify: false);
    _drawingController.dispose();
    super.dispose();
  }

  Widget _buildBorder(BuildContext context, bool usePaper) {
    final text = Text(
      widget.label.text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
      ),
    );

    if (usePaper) {
      final drawingProgress = _drawingController.value;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: text,
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: HandDrawnRectanglePainter(
                color: Colors.blue,
                progress: drawingProgress,
                cornerRadius: 0,
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border.all(color: Colors.blue, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the pooled controller assigned to this label
    final animationController = widget.controller.getControllerForLabel(widget.label.id);

    if (animationController == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, _) {
        final position = _calculateLabelPosition(
          animationController.value,
          widget.edgeData.curveBend,
        );
        final angle = _calculateLabelAngle(animationController.value, widget.edgeData.curveBend);
        final opacity = _calculateLabelOpacity(animationController.value);

        return Positioned(
          left: position.dx - 20,
          top: position.dy - 10,
          child: Transform.rotate(
            angle: angle,
            child: Opacity(
              opacity: opacity,
              child: _buildBorder(context, true),
            ),
          ),
        );
      },
    );
  }

  Offset _calculateLabelPosition(double t, double curveBend) {
    final fromNode = widget.graph.getNode(widget.edgeData.fromNodeId);
    final toNode = widget.graph.getNode(widget.edgeData.toNodeId);

    if (fromNode == null || toNode == null) return Offset.zero;

    final fromPos = widget.nodeScreenPositions[fromNode.id];
    final toPos = widget.nodeScreenPositions[toNode.id];

    if (fromPos == null || toPos == null) return Offset.zero;

    // Stub: Calculate position along bezier curve at animation progress
    // Actual implementation uses BezierUtils.evaluateCubicBezier
    final (cp1, cp2) = BezierUtils.calculateControlPoints(
      fromPos,
      toPos,
      EdgesPainter.controlPointHorizontalOffset,
      curveBend,
    );

    return BezierUtils.evaluateCubicBezier(fromPos, cp1, cp2, toPos, t);
  }

  double _calculateLabelAngle(double t, double curveBend) {
    final fromNode = widget.graph.getNode(widget.edgeData.fromNodeId);
    final toNode = widget.graph.getNode(widget.edgeData.toNodeId);

    if (fromNode == null || toNode == null) return 0;

    final fromPos = widget.nodeScreenPositions[fromNode.id];
    final toPos = widget.nodeScreenPositions[toNode.id];

    if (fromPos == null || toPos == null) return 0;

    final (cp1, cp2) = BezierUtils.calculateControlPoints(
      fromPos,
      toPos,
      EdgesPainter.controlPointHorizontalOffset,
      curveBend,
    );

    final tangent = BezierUtils.evaluateCubicBezierTangent(fromPos, cp1, cp2, toPos, t);
    var angle = math.atan2(tangent.dy, tangent.dx);

    // Normalize angle to keep text upright: constrain to [-π/2, π/2]
    if (angle > math.pi / 2) {
      angle -= math.pi;
    } else if (angle < -math.pi / 2) {
      angle += math.pi;
    }

    return angle;
  }

  double _calculateLabelOpacity(double t) {
    // Stub: Fade in and out at edges of animation
    const fadeDistance = 0.15;

    if (t < fadeDistance) {
      return t / fadeDistance;
    } else if (t > 1.0 - fadeDistance) {
      return (1.0 - t) / fadeDistance;
    }
    return 1.0;
  }
}
