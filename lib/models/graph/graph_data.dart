// graph_data.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/graph/interceptor.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:collection/collection.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

abstract class GraphNodeData {
  /// Graph-unique node id
  String get id;

  /// Where to draw the node on the main screen. Normalized [0,1]
  Offset get logicalPosition;
  set logicalPosition(Offset value);

  /// What to draw inside the node, typically just the node's label
  NodeContents get contents;

  /// State of this node: in-progress, disabled, idle, etc
  NodeState get nodeState;

  /// Sets the node state. It's a function so that we can properly send events back to the GraphEventBus
  void setNodeState(NodeState nodeState, {bool notify = true, bool force = false});

  Future<ProcessResult<Object?>> process(DataPacket<Object?> input);
}

/// A node whose processor returns a [RouteDecision] instead of manually emitting events.
///
/// Side effects are handled by [interceptors] which run before the processor.
/// The processor is a pure routing function: it receives the data packet and
/// a [GraphRouter], and returns a [RouteDecision] expressing where data should go.
class RoutedGraphNodeData<Tin extends Object, Tout extends Object> extends GraphNodeData {
  @override
  final String id;
  @override
  Offset logicalPosition;
  @override
  final NodeContents contents;
  @override
  NodeState get nodeState => _nodeState;
  NodeState _nodeState;

  final Function(NodeState oldState, NodeState newState)? onUpdateState;
  final List<ProcessInterceptor> interceptors;
  final Future<RouteDecision> Function(DataPacket<Tin?>, GraphRouter router) processor;
  final GraphRouter _router;

  RoutedGraphNodeData({
    required this.id,
    required this.logicalPosition,
    required this.contents,
    required NodeState nodeState,
    required this.processor,
    required GraphRouter router,
    this.onUpdateState,
    this.interceptors = const [],
  }) : _nodeState = nodeState,
       _router = router;

  @override
  Future<ProcessResult<Object?>> process(Object? input) async {
    if (input == null) {
      throw Exception("RoutedGraphNodeData process input must not be null");
    }
    // Recast from DataPacket<Object?> (event bus) to DataPacket<Tin?> (typed processor)
    DataPacket<Tin?> packet = (input as DataPacket).recast<Tin?>();

    // Run interceptors in order
    for (final interceptor in interceptors) {
      if (!interceptor.shouldFire(packet)) continue;

      final ctx = InterceptContext(
        flowController: _router.flowController,
        getContext: _router.contextFetcher,
        nodeId: id,
      );
      final result = await interceptor.execute(packet, ctx);
      switch (result) {
        case ContinueResult():
          packet = result.packet.recast<Tin?>();
        case ShortCircuitResult():
          _router.executeRoute(id, result.decision);
          return ProcessResult(state: result.decision.resultingNodeState);
      }
    }

    // Run the pure processor
    final decision = await processor(packet, _router);
    _router.executeRoute(id, decision);
    return ProcessResult(state: decision.resultingNodeState);
  }

  @override
  void setNodeState(NodeState newNodeState, {bool notify = true, bool force = false}) {
    final oldState = _nodeState;
    _nodeState = newNodeState;

    if (notify && oldState != newNodeState) {
      onUpdateState?.call(oldState, newNodeState);
    }
  }
}

class GraphEdgeData {
  final String fromNodeId;
  final String toNodeId;

  /// Optional text that should be statically displayed as a label for this edge
  final String? label;
  final Widget? labelWidget;

  /// How to offset the label, for example, so that it isn't drawn directly over the edge itself. Defaults to `Offset.zero`
  final Offset labelOffset;

  /// Where, as a percentage [0,1], should the arrowhead indicating direction of this edge, be drawn
  final double arrowPositionAlongCurveAsPercent;

  /// How strong to bend the edge, graphically. Unbounded in both directions [-inf, +inf]
  double curveBend;

  /// If true, the arrow is drawn 180 degrees
  final bool isReverseArrow;

  /// The graph-unique id of this edge
  final String id;

  /// State of this Edge (idle, disabled, etc)
  EdgeState edgeState;

  GraphEdgeData({
    required this.fromNodeId,
    required this.toNodeId,
    required this.id,
    this.labelWidget,
    this.label,
    this.arrowPositionAlongCurveAsPercent = 0.5,
    this.curveBend = 0,
    this.edgeState = EdgeState.idle,
    this.labelOffset = Offset.zero,
    this.isReverseArrow = false,
  });

  @override
  String toString() {
    return "$fromNodeId ==> $toNodeId";
  }
}

/// Observable graph that notifies listeners when nodes or edges are added/removed.
class ControlFlowGraph extends ChangeNotifier {
  final List<GraphNodeData> _nodes;
  final List<GraphEdgeData> _edges;
  String? startingNodeId;
  final GraphProperties properties;

  ControlFlowGraph({
    required List<GraphNodeData> nodes,
    required List<GraphEdgeData> edges,
    required this.properties,
    this.startingNodeId,
  }) : _nodes = List.of(nodes),
       _edges = List.of(edges);

  List<GraphNodeData> get nodes => _nodes;
  List<GraphEdgeData> get edges => _edges;

  /// Add a node at runtime. UI rebuilds automatically via ChangeNotifier.
  void addNode(GraphNodeData node) {
    _nodes.add(node);
    notifyListeners();
  }

  /// Remove a node and all its connected edges.
  void removeNode(String nodeId) {
    _nodes.removeWhere((n) => n.id == nodeId);
    _edges.removeWhere((e) => e.fromNodeId == nodeId || e.toNodeId == nodeId);
    notifyListeners();
  }

  /// Add an edge at runtime.
  void addEdge(GraphEdgeData edge) {
    _edges.add(edge);
    notifyListeners();
  }

  /// Remove an edge by ID.
  void removeEdge(String edgeId) {
    _edges.removeWhere((e) => e.id == edgeId);
    notifyListeners();
  }

  /// Returns the Node given by this id
  GraphNodeData? getNode(String id) => _nodes.firstWhereOrNull((n) => n.id == id);

  /// Returns any outgoing edges for the node given by this id
  List<GraphEdgeData> getOutgoingEdges(String nodeId) => _edges.where((c) => c.fromNodeId == nodeId).toList();

  /// Returns incoming edges for the node given by this id
  List<GraphEdgeData> getIncomingEdges(String nodeId) => _edges.where((c) => c.toNodeId == nodeId).toList();

  /// Returns all incoming and outgoing edges for the node given by the id
  List<GraphEdgeData> getEdges(String nodeId) => [...getOutgoingEdges(nodeId), ...getIncomingEdges(nodeId)];
}

enum EdgeState {
  /// Edge is currently not doing anything special
  idle,

  /// Edge is currently transmitting a DataPacket / AnimatedLabel
  inProgress,

  /// Edge has errored, and is not useable
  error,

  /// Edge is disabled, no data may travel over this edge in this state
  disabled,
}

class GraphProperties {
  /// Some graphs are automatic, meaning that after initial kickoff, the process is purely functional with no dependencies like I/O, and therefore can be automatically repeated
  final bool isAutomatic;

  /// Some graphs have a defined end point
  final bool hasEnd;

  /// Some graphs, for demonstration purposes, handle their own travel time settings
  final bool hasTuneableTravelTime;

  /// Some graphs, for demonstration purposes, handle their own processing time settings
  final bool hasTuneableProcessingTime;

  /// Some graphs permit going step by step, like an IDE debugger
  final bool canStepDebug;

  /// Some graphs can show a State Manager like an IDE callstack and watch values
  final bool canShowCurrentState;

  const GraphProperties({
    this.isAutomatic = false,
    this.hasEnd = false,
    this.hasTuneableTravelTime = false,
    this.hasTuneableProcessingTime = false,
    this.canStepDebug = false,
    this.canShowCurrentState = false,
  });
}
