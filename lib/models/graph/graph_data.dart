// graph_data.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:collection/collection.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

abstract class GraphNodeData {
  /// Grpah-unique node-id
  String get id;

  /// Where to draw the node on the main screen. Normalized [0,1]
  Offset get logicalPosition;

  /// What to draw inside the node, typically just the nodes label
  NodeContents get contents;

  /// State of this node, in-progress, disabled, idle, etc
  NodeState get nodeState;

  /// sets the node state. Its a function so that we can properly send events back to the GraphEventBus
  void setNodeState(NodeState nodeState, {bool notify = true, bool force = false});

  Future<ProcessResult<Object>> process(Object? input);
}

class TypedGraphNodeData<Tin extends Object, Tout extends Object> extends GraphNodeData {
  @override
  final String id;
  @override
  final Offset logicalPosition; // normalized [0,1]
  @override
  final NodeContents contents;
  @override
  NodeState get nodeState => _nodeState;
  NodeState _nodeState;

  final Function(NodeState oldState, NodeState newState)? onUpdateState;
  final Future<ProcessResult<Tout>> Function(Tin?) processor;

  TypedGraphNodeData({
    required this.id,
    required this.logicalPosition,
    required this.contents,
    required NodeState nodeState,
    required this.processor,
    this.onUpdateState,
  }) : _nodeState = nodeState;

  @override
  Future<ProcessResult<Object>> process(Object? input) async {
    if (input == null) {
      throw Exception("Although the inner processor functions can accept an eventually-unwrapped null, the TypedGraphNode process input must not be null");
    }
    final dp = input as DataPacket<Tin>;
    final result = await processor(dp.actualData);
    return ProcessResult<Object>(
      state: result.state,
      message: result.message,
      data: result.data,
    );
  }

  @override
  void setNodeState(NodeState newNodeState, {bool notify = true, bool force = false}) {
    final oldState = _nodeState;
    _nodeState = newNodeState;

    // Only notify after state is updated to prevent recursive calls
    if (notify && oldState != newNodeState) {
      onUpdateState?.call(oldState, newNodeState);
    }
  }
}

class GraphEdgeData {
  final String fromNodeId;
  final String toNodeId;

  /// Optional text that should be statically displayed as a lebel for this edge
  final String? label;

  /// How to offset the label, for example, so that it isn't drawn directly over the edge itself. Defaults to `Offset.Zero`
  final Offset labelOffset;

  /// Where, as a percentage [0,1], should the arrowhead indicating direction of this edge, be drawn
  final double arrowPositionAlongCurveAsPercent;

  /// How strong to bend the edge, graphically. Unbounded in both directions [-inf, +inf]
  final double curveBend;

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

class ControlFlowGraph {
  final List<GraphNodeData> nodes;
  final List<GraphEdgeData> edges;
  final String? startingNodeId;
  final GraphProperties properties;

  ControlFlowGraph({
    required this.nodes,
    required this.edges,
    required this.properties,
    this.startingNodeId,
  });

  /// returns the Node given by this id
  GraphNodeData? getNode(String id) => nodes.firstWhereOrNull((n) => n.id == id);

  /// Returns any outgoing edges for the node given by this id
  List<GraphEdgeData> getOutgoingEdges(String nodeId) => edges.where((c) => c.fromNodeId == nodeId).toList();

  /// Returns incoming edges for the node given by this id
  List<GraphEdgeData> getIncomingEdges(String nodeId) => edges.where((c) => c.toNodeId == nodeId).toList();

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

  /// Edge is disabld, no data may travel over this edge in this state
  disabled,
}

class GraphProperties {
  /// some graphs are automatic, meaning that after initial kickoff, the process is Purely Funtional with no dependencies like i/o, and therefore can be automatically repeated
  final bool isAutomatic;

  /// Some graphs have a defined end point
  final bool hasEnd;

  /// Some graphs, for demonstration purposes, handle their own travel time settings
  final bool hasTuneableTravelTime;

  /// Some graphs, for demonstration purposes, handle their own Processing Time settings
  final bool hasTuneableProcessingTime;

  /// Some graphs permit going step by step, like an IDE debugge
  final bool canStepDebug;

  /// Some graphs can show a State Manager like an IDE callstack and watch values
  final bool canShowCurrentState;

  GraphProperties({
    required this.isAutomatic,
    required this.hasEnd,
    required this.hasTuneableTravelTime,
    required this.hasTuneableProcessingTime,
    required this.canStepDebug,
    required this.canShowCurrentState,
  });
}
