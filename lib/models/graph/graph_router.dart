import 'dart:math';

import 'package:collection/collection.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

/// A routing decision returned by a processor.
/// The processor says WHERE to go; the router handles HOW.
class RouteDecision {
  final String? toNodeId;
  final String? edgeId;
  final String label;
  final Object? data;
  final bool disableEdgeAfter;
  final bool disableNodeAfter;
  final Duration? travelDuration;
  final NodeState resultingNodeState;

  /// Route data along a specific edge (identified by edgeId).
  const RouteDecision({
    required this.toNodeId,
    required this.edgeId,
    this.label = "",
    this.data,
    this.disableEdgeAfter = true,
    this.disableNodeAfter = false,
    this.travelDuration,
    this.resultingNodeState = NodeState.selected,
  });

  /// Route to a node; the router picks the first enabled edge between source and target.
  const RouteDecision.toNode({
    required this.toNodeId,
    this.label = "",
    this.data,
    this.disableEdgeAfter = true,
    this.disableNodeAfter = false,
    this.travelDuration,
    this.resultingNodeState = NodeState.selected,
  }) : edgeId = null;

  /// Don't route anywhere, just set the node state (used for end nodes, errors, etc).
  const RouteDecision.terminal({
    this.resultingNodeState = NodeState.selected,
  })  : toNodeId = null,
        edgeId = null,
        label = "",
        data = null,
        disableEdgeAfter = false,
        disableNodeAfter = false,
        travelDuration = null;

  /// Whether this is a terminal decision (no routing).
  bool get isTerminal => toNodeId == null;
}

/// The router sits between processors and the event bus.
/// It takes a RouteDecision and handles all the edge lookup, event emission,
/// and disable-after-processing mechanics.
class GraphRouter {
  final GraphFlowController flowController;
  final FnContextFetcher contextFetcher;
  ControlFlowGraph graph;

  GraphRouter({
    required this.flowController,
    required this.contextFetcher,
    required this.graph,
  });

  GraphEventBus get eventBus => flowController.dataFlowEventBus;

  /// Current travel duration from inherited settings.
  Duration get travelDuration => InheritedGraphConfigSettings.of(contextFetcher()).stepSettings.travelDuration;

  /// Current processing duration from inherited settings.
  Duration get processingDuration => InheritedGraphConfigSettings.of(contextFetcher()).stepSettings.processingDuration;

  /// Execute a routing decision: look up the edge, emit DataExitedEvent.
  /// This replaces the ~15 lines of boilerplate in every processor.
  void executeRoute(String fromNodeId, RouteDecision decision) {
    if (decision.isTerminal) return;

    final toNodeId = decision.toNodeId!;
    GraphEdgeData? edge;

    if (decision.edgeId != null) {
      edge = graph.edges.firstWhereOrNull(
        (e) => e.id == decision.edgeId && e.edgeState != EdgeState.disabled,
      );
    } else {
      // Find the first enabled edge between source and target
      edge = findEdge(fromNodeId, toNodeId);
    }

    if (edge == null || toNodeId.isEmpty) return;

    flowController.dataFlowEventBus.emit(
      DataExitedEvent(
        cameFromNodeId: fromNodeId,
        goingToNodeId: toNodeId,
        edgeId: edge.id,
        data: DataPacket<Object>(
          labelText: decision.label,
          actualData: decision.data,
          fromNodeId: fromNodeId,
          toNodeId: toNodeId,
          toEdgeId: edge.id,
        ),
        disableEdgeAfter: decision.disableEdgeAfter,
        disableNodeAfter: decision.disableNodeAfter,
        duration: decision.travelDuration ?? travelDuration,
      ),
    );
  }

  /// Find the first enabled edge between two nodes.
  GraphEdgeData? findEdge(String fromNodeId, String toNodeId) {
    return graph.edges.firstWhereOrNull(
      (e) => e.fromNodeId == fromNodeId && e.toNodeId == toNodeId && e.edgeState != EdgeState.disabled,
    );
  }

  /// Find a specific edge by its ID, if enabled.
  GraphEdgeData? findEdgeById(String edgeId) {
    return graph.edges.firstWhereOrNull(
      (e) => e.id == edgeId && e.edgeState != EdgeState.disabled,
    );
  }

  /// Pick a random enabled outgoing edge from a node. Returns null if none available.
  /// Convenience for racers-style random routing.
  RouteDecision? randomOutgoingEdge(
    String fromNodeId, {
    String label = "",
    Object? data,
    bool disableEdgeAfter = false,
    bool disableNodeAfter = false,
    Duration? travelDuration,
    NodeState resultingNodeState = NodeState.selected,
  }) {
    final edges = graph.getOutgoingEdges(fromNodeId).where((e) => e.edgeState != EdgeState.disabled).toList();
    if (edges.isEmpty) return null;
    final edge = edges[Random().nextInt(edges.length)];
    return RouteDecision(
      toNodeId: edge.toNodeId,
      edgeId: edge.id,
      label: label,
      data: data,
      disableEdgeAfter: disableEdgeAfter,
      disableNodeAfter: disableNodeAfter,
      travelDuration: travelDuration,
      resultingNodeState: resultingNodeState,
    );
  }
}
