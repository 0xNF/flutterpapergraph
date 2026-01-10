import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/connection.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:collection/collection.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

abstract class GraphNodeData {
  String get id;
  Offset get logicalPosition;
  NodeContents get contents;
  NodeState get nodeState;

  void setNodeState(NodeState nodeState, {bool notify = true, bool force = false});

  Future<ProcessResult<Object>> process(Object? input);
}

class TypedGraphNodeData<Tin extends Object, Tout extends Object> extends GraphNodeData {
  @override
  final String id;
  @override
  final Offset logicalPosition; // normalized 0-1
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

class GraphConnectionData {
  final String fromId;
  final String toId;
  final String? label;
  final double arrowPositionAlongCurve;
  final double curveBend;
  final Offset labelOffset;
  final bool reverseArrow;
  final String connectionId;
  ConnectionState connectionState;

  ConnectionLink get connectionLink => "$fromId-$toId";

  GraphConnectionData({
    required this.fromId,
    required this.toId,
    required this.connectionId,
    this.label,
    this.arrowPositionAlongCurve = 0.5,
    this.curveBend = 0,
    this.connectionState = ConnectionState.idle,
    this.labelOffset = Offset.zero,
    this.reverseArrow = false,
  });

  @override
  String toString() {
    return "$fromId ==> $toId";
  }
}

class ControlFlowGraph {
  final List<GraphNodeData> nodes;
  final List<GraphConnectionData> connections;

  ControlFlowGraph({
    required this.nodes,
    required this.connections,
  });

  GraphNodeData? getNode(String id) => nodes.firstWhereOrNull((n) => n.id == id);

  List<GraphConnectionData> getConnectionsFrom(String nodeId) => connections.where((c) => c.fromId == nodeId).toList();

  List<GraphConnectionData> getConnectionsTo(String nodeId) => connections.where((c) => c.toId == nodeId).toList();

  List<GraphConnectionData> getConnectionsFor(String nodeId) => [...getConnectionsFrom(nodeId), ...getConnectionsTo(nodeId)];
}

enum ConnectionState { idle, inProgress, error, disabled }
