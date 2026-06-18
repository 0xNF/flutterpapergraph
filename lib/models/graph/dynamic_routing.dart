import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';

/// Routing strategy for dynamically-added graph nodes.
enum DynamicRoutingStrategy {
  /// Route data along the first enabled outgoing edge.
  forward,

  /// Route data along a random enabled outgoing edge.
  random,

  /// Send data to ALL enabled outgoing edges simultaneously.
  broadcast,

  /// Route to a specific edge or node by ID.
  directed,
}

/// Creates a processor function for a dynamic node based on its routing strategy.
///
/// For [DynamicRoutingStrategy.directed], provide [directedTargetEdgeId] or
/// [directedTargetNodeId] to specify the routing target.
Future<RouteDecision> Function(DataPacket<String?>, GraphRouter) makeDynamicProcessor(
  DynamicRoutingStrategy strategy,
  String nodeId, {
  String? directedTargetEdgeId,
  String? directedTargetNodeId,
}) {
  return switch (strategy) {
    DynamicRoutingStrategy.forward => (d, r) async {
      final edges = r.graph.getOutgoingEdges(nodeId).where((e) => e.edgeState != EdgeState.disabled).toList();
      if (edges.isEmpty) return RouteDecision.terminal();
      final edge = edges.first;
      return RouteDecision(
        toNodeId: edge.toNodeId,
        edgeId: edge.id,
        label: d.labelText,
        data: d.actualData,
      );
    },
    DynamicRoutingStrategy.random => (d, r) async {
      return r.randomOutgoingEdge(
            nodeId,
            label: d.labelText,
            data: d.actualData,
            disableEdgeAfter: false,
          ) ??
          RouteDecision.terminal();
    },
    DynamicRoutingStrategy.broadcast => (d, r) async {
      final edges = r.graph.getOutgoingEdges(nodeId).where((e) => e.edgeState != EdgeState.disabled).toList();
      if (edges.isEmpty) return RouteDecision.terminal();
      // Execute routing for all edges except the last one
      for (int i = 0; i < edges.length - 1; i++) {
        r.executeRoute(
          nodeId,
          RouteDecision(
            toNodeId: edges[i].toNodeId,
            edgeId: edges[i].id,
            label: d.labelText,
            data: d.actualData,
            disableEdgeAfter: false,
          ),
        );
      }
      // Return the last edge as the processor's own decision
      final last = edges.last;
      return RouteDecision(
        toNodeId: last.toNodeId,
        edgeId: last.id,
        label: d.labelText,
        data: d.actualData,
        disableEdgeAfter: false,
      );
    },
    DynamicRoutingStrategy.directed => (d, r) async {
      // Route by edge ID if provided
      if (directedTargetEdgeId != null) {
        final edge = r.findEdgeById(directedTargetEdgeId);
        if (edge != null) {
          return RouteDecision(
            toNodeId: edge.toNodeId,
            edgeId: edge.id,
            label: d.labelText,
            data: d.actualData,
          );
        }
        return RouteDecision.terminal();
      }
      // Route by node ID
      if (directedTargetNodeId != null) {
        return RouteDecision.toNode(
          toNodeId: directedTargetNodeId,
          label: d.labelText,
          data: d.actualData,
        );
      }
      return RouteDecision.terminal();
    },
  };
}
