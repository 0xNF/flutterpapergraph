import 'package:flutter/widgets.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/graph/interceptor.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

/// Deferred node definition, resolved at build time when router and callbacks are available.
class _NodeDef<Tin extends Object, Tout extends Object> {
  final String id;
  final Offset position;
  final NodeContents contents;
  final NodeState initialState;
  final List<ProcessInterceptor> interceptors;
  final Future<RouteDecision> Function(DataPacket<Tin?>, GraphRouter router) processor;

  _NodeDef({
    required this.id,
    required this.position,
    required this.contents,
    required this.initialState,
    required this.interceptors,
    required this.processor,
  });

  /// Build the [RoutedGraphNodeData] with preserved generic types.
  /// Called via dynamic dispatch so Tin/Tout are the concrete types,
  /// not the erased Object/Object from the raw List<_NodeDef>.
  RoutedGraphNodeData<Tin, Tout> buildNode(GraphRouter router, FnNodeStateCallback onUpdateNodeState) {
    return RoutedGraphNodeData<Tin, Tout>(
      id: id,
      logicalPosition: position,
      contents: contents,
      nodeState: initialState,
      interceptors: interceptors,
      processor: processor,
      router: router,
      onUpdateState: (o, n) => onUpdateNodeState(id, o, n, true),
    );
  }
}

/// Fluent builder for constructing [ControlFlowGraph] instances.
///
/// Define edges first (so their auto-generated IDs are available for interceptors),
/// then nodes. Call [build] to produce the final graph.
///
/// ```dart
/// final graph = (GraphBuilder()
///   ..startAt('user')
///   ..properties(isAutomatic: true, hasEnd: true)
///   ..edge('user', 'server', label: 'request', curveBend: -100)
///   ..edge('server', 'user', label: 'response', curveBend: 100)
///   ..node('user', position: Offset(0.1, 0.3), title: "User",
///     processor: (packet, router) async => RouteDecision.toNode(toNodeId: 'server'))
///   ..node('server', position: Offset(0.8, 0.3), title: "Server",
///     processor: (packet, router) async => RouteDecision.terminal())
/// ).build(router: router, onUpdateNodeState: callback);
/// ```
class GraphBuilder {
  String? _startingNodeId;
  GraphProperties _properties = const GraphProperties();
  final List<_NodeDef> _nodeDefs = [];
  final List<GraphEdgeData> _edges = [];
  int _edgeCounter = 0;

  /// Set the starting node ID.
  void startAt(String nodeId) {
    _startingNodeId = nodeId;
  }

  /// Set graph properties. All default to false.
  void properties({
    bool isAutomatic = false,
    bool hasEnd = false,
    bool hasTuneableTravelTime = false,
    bool hasTuneableProcessingTime = false,
    bool canStepDebug = false,
    bool canShowCurrentState = false,
  }) {
    _properties = GraphProperties(
      isAutomatic: isAutomatic,
      hasEnd: hasEnd,
      hasTuneableTravelTime: hasTuneableTravelTime,
      hasTuneableProcessingTime: hasTuneableProcessingTime,
      canStepDebug: canStepDebug,
      canShowCurrentState: canShowCurrentState,
    );
  }

  /// Add an edge. Returns the edge ID (auto-generated if not provided).
  ///
  /// Only edges that need to be referenced by interceptors require explicit IDs.
  /// All others get auto-generated IDs in the form `'{counter}_{from}_to_{to}'`.
  String edge(
    String fromNodeId,
    String toNodeId, {
    String? id,
    String? label,
    Widget? labelWidget,
    double curveBend = 0,
    Offset labelOffset = Offset.zero,
    double arrowPosition = 0.5,
    bool isReverseArrow = false,
  }) {
    final edgeId = id ?? '${_edgeCounter++}_${fromNodeId}_to_$toNodeId';
    _edges.add(GraphEdgeData(
      id: edgeId,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      label: label,
      labelWidget: labelWidget,
      curveBend: curveBend,
      labelOffset: labelOffset,
      arrowPositionAlongCurveAsPercent: arrowPosition,
      isReverseArrow: isReverseArrow,
    ));
    return edgeId;
  }

  /// Add a node with a routed processor and optional interceptors.
  void node<Tin extends Object, Tout extends Object>(
    String id, {
    required Offset position,
    required String title,
    TextStyle? textStyle,
    NodeState initialState = NodeState.unselected,
    List<ProcessInterceptor> interceptors = const [],
    required Future<RouteDecision> Function(DataPacket<Tin?>, GraphRouter router) processor,
  }) {
    _nodeDefs.add(_NodeDef<Tin, Tout>(
      id: id,
      position: position,
      contents: textStyle != null ? NodeContents(stepTitle: title, textStyle: textStyle) : NodeContents(stepTitle: title),
      initialState: initialState,
      interceptors: interceptors,
      processor: processor,
    ));
  }

  /// Build the final [ControlFlowGraph].
  ///
  /// [router] is wired into each [RoutedGraphNodeData] so processors can use it.
  /// [onUpdateNodeState] is the callback for node state changes.
  ControlFlowGraph build({
    required GraphRouter router,
    required FnNodeStateCallback onUpdateNodeState,
  }) {
    assert(_startingNodeId != null, 'GraphBuilder: startAt() must be called before build()');

    final nodes = _nodeDefs.map((def) => def.buildNode(router, onUpdateNodeState)).toList();

    final graph = ControlFlowGraph(
      nodes: nodes,
      edges: _edges,
      startingNodeId: _startingNodeId,
      properties: _properties,
    );

    // Wire the router to this graph
    router.graph = graph;

    return graph;
  }
}
