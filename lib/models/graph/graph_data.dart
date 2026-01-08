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

  Future<ProcessResult<Object>> process(Object input);
}

class TypedGraphNodeData<Tin extends Object, Tout extends Object> extends GraphNodeData {
  @override
  final String id;
  @override
  final Offset logicalPosition; // normalized 0-1
  @override
  final NodeContents contents;
  @override
  final NodeState nodeState;
  final Future<ProcessResult<Tout>> Function(Tin) processor;

  TypedGraphNodeData({
    required this.id,
    required this.logicalPosition,
    required this.contents,
    required this.nodeState,
    required this.processor,
  });

  @override
  Future<ProcessResult<Object>> process(Object input) async {
    final dp = input as DataPacket<Tin>;
    final result = await processor(dp.actualData!);
    return ProcessResult<Object>(
      state: result.state,
      message: result.message,
      data: result.data,
    );
  }
}

class GraphConnectionData {
  final String fromId;
  final String toId;
  final String? label;
  final double arrowPositionAlongCurve;
  final double curveBend;

  ConnectionId get connectionId => "$fromId-$toId";

  GraphConnectionData({
    required this.fromId,
    required this.toId,
    this.label,
    this.arrowPositionAlongCurve = 0.5,
    this.curveBend = 0,
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
}
