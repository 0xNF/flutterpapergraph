// edges_widget.dart

import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/painters/edgespainter.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class EdgesWidget extends StatefulWidget {
  final ControlFlowGraph graph;
  final Map<String, Offset> nodeScreenPositions;
  final GraphFlowController controller;
  final Size containerSize;
  final EdgeSettings edgeSettings;
  final bool usePaper;
  final PaperSettings? paperSettings;
  final double drawingProgress;
  final Map<String, int> edgeSeeds;

  const EdgesWidget({
    required this.graph,
    required this.nodeScreenPositions,
    required this.controller,
    required this.containerSize,
    required this.edgeSettings,
    required this.usePaper,
    required this.paperSettings,
    required this.drawingProgress,
    required this.edgeSeeds,
  });

  @override
  State<EdgesWidget> createState() => _EdgesWidgetState();
}

class _EdgesWidgetState extends State<EdgesWidget> {
  late EdgesPainter _edgesPainter;
  GraphEdgeData? _draggedEdge;
  Offset _lastDragPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _updatePainter();
  }

  @override
  void didUpdateWidget(EdgesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePainter();
  }

  void _updatePainter() {
    _edgesPainter = EdgesPainter(
      graph: widget.graph,
      nodeScreenPositions: widget.nodeScreenPositions,
      controller: widget.controller,
      containerSize: widget.containerSize,
      edgeSettings: widget.edgeSettings,
      usePaper: widget.usePaper,
      paperSettings: widget.paperSettings,
      drawingProgress: widget.drawingProgress,
      edgeSeeds: widget.edgeSeeds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (DragStartDetails details) {
        // Check if user clicked on an edge
        _draggedEdge = _edgesPainter.hitTestEdge(details.globalPosition);
        _lastDragPosition = details.globalPosition;
      },
      onPanUpdate: (DragUpdateDetails details) {
        if (_draggedEdge == null) return;

        final fromNode = widget.graph.getNode(_draggedEdge!.fromNodeId);
        final toNode = widget.graph.getNode(_draggedEdge!.toNodeId);

        if (fromNode == null || toNode == null) return;

        final fromPos = widget.nodeScreenPositions[fromNode.id];
        final toPos = widget.nodeScreenPositions[toNode.id];

        if (fromPos == null || toPos == null) return;

        // Calculate the new curve bend based on the drag
        final curveBendDelta = _edgesPainter.calculateCurveBendDelta(
          _lastDragPosition,
          details.globalPosition,
          fromPos,
          toPos,
          _draggedEdge!.curveBend,
        );

        // Update the edge's curve bend
        final newCurveBend = _draggedEdge!.curveBend + curveBendDelta;
        print('Drag delta: $curveBendDelta, New bend: $newCurveBend');
        _draggedEdge!.curveBend = newCurveBend;

        _lastDragPosition = details.globalPosition;
        setState(() {});
      },
      onPanEnd: (_) {
        _draggedEdge = null;
      },
      child: MouseRegion(
        cursor: _draggedEdge != null ? SystemMouseCursors.grab : MouseCursor.defer,
        child: CustomPaint(
          painter: _edgesPainter,
          size: widget.containerSize,
        ),
      ),
    );
  }
}
