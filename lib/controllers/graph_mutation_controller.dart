import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:oauthclient/models/graph/dynamic_routing.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

/// Controller for adding/removing nodes and edges on a live [ControlFlowGraph].
///
/// Sits between callers (UI buttons now, HTTP later) and the graph's raw
/// mutation methods. Handles ID generation, auto-positioning, and wiring up
/// dynamic processors.
class GraphMutationController {
  final ControlFlowGraph graph;
  final GraphRouter router;
  final FnNodeStateCallback onUpdateNodeState;

  int _edgeCounter = 0;
  int _nodeCounter = 0;

  GraphMutationController({
    required this.graph,
    required this.router,
    required this.onUpdateNodeState,
  });

  /// Add or update a dynamic node.
  ///
  /// If a node with [id] already exists, updates its position and state.
  /// Otherwise creates a new node. Returns the node's ID (auto-generated if
  /// [id] is null).
  ///
  /// If [position] is null on creation, the node is placed using golden-angle
  /// auto-layout. If null on update, the position is left unchanged.
  String upsertDynamicNode({
    String? id,
    required String title,
    Offset? position,
    NodeState state = NodeState.unselected,
    DynamicRoutingStrategy strategy = DynamicRoutingStrategy.forward,
    String? directedTargetEdgeId,
    String? directedTargetNodeId,
  }) {
    final nodeId = id ?? 'dyn_node_${_nodeCounter++}';

    // Update existing node
    final existing = graph.getNode(nodeId);
    if (existing != null) {
      if (position != null) {
        existing.logicalPosition = position;
      }
      existing.setNodeState(state);
      graph.markDirty();
      return nodeId;
    }

    // Create new node
    final pos = position ?? _autoPosition();

    final processor = makeDynamicProcessor(
      strategy,
      nodeId,
      directedTargetEdgeId: directedTargetEdgeId,
      directedTargetNodeId: directedTargetNodeId,
    );

    final node = RoutedGraphNodeData<String, String>(
      id: nodeId,
      logicalPosition: pos,
      contents: NodeContents(stepTitle: title),
      nodeState: state,
      processor: processor,
      router: router,
      onUpdateState: (oldState, newState) =>
          onUpdateNodeState(nodeId, oldState, newState, true),
    );

    graph.addNode(node);
    return nodeId;
  }

  /// Add a dynamic edge between two existing nodes.
  ///
  /// Returns the edge's ID (auto-generated if [id] is null).
  String addDynamicEdge({
    String? id,
    required String fromNodeId,
    required String toNodeId,
    String? label,
    double curveBend = 0,
  }) {
    final edgeId = id ?? 'dyn_${_edgeCounter++}_${fromNodeId}_to_$toNodeId';

    final edge = GraphEdgeData(
      id: edgeId,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      label: label,
      curveBend: curveBend,
    );

    graph.addEdge(edge);
    return edgeId;
  }

  void removeNode(String nodeId) => graph.removeNode(nodeId);

  void removeEdge(String edgeId) => graph.removeEdge(edgeId);

  /// Place nodes around (0.5, 0.5) using the golden angle so each
  /// successive node lands in a visually distinct position.
  Offset _autoPosition() {
    final index = graph.nodes.length;
    const goldenAngle = 2.399963; // radians
    final angle = index * goldenAngle;
    return Offset(
      (0.5 + 0.3 * cos(angle)).clamp(0.05, 0.95),
      (0.5 + 0.3 * sin(angle)).clamp(0.05, 0.95),
    );
  }
}
