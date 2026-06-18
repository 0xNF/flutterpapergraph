import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

ControlFlowGraph racers(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  final r = math.Random(DateTime.now().millisecondsSinceEpoch);

  Duration selectDurationQuadratic() {
    double normalized = r.nextDouble();
    double biased = 0.5 + (normalized - 0.5) * (1 - (normalized - 0.5).abs());
    int milliseconds = (100 + biased * 1900).toInt();
    return Duration(milliseconds: milliseconds);
  }

  Future<RouteDecision> racerProcessor(String nodeId) async {
    await Future.delayed(selectDurationQuadratic());
    return router.randomOutgoingEdge(
          nodeId,
          label: "f${nodeId.replaceAll('node', '')}",
          data: "x",
          travelDuration: selectDurationQuadratic(),
        ) ??
        RouteDecision.terminal(resultingNodeState: NodeState.selected);
  }

  const node1 = "node1";
  const node2 = "node2";
  const node3 = "node3";
  const node4 = "node4";
  const node5 = "node5";

  final builder = GraphBuilder()
    ..startAt(node1)
    ..properties(isAutomatic: true, hasEnd: false)
    ..edge(node1, node2, label: 'init', curveBend: 500)
    ..edge(node2, node3, label: 'continue')
    ..edge(node3, node4, label: 'yes', curveBend: -200)
    ..edge(node3, node5, label: 'no', curveBend: 300)
    ..edge(node4, node5, curveBend: -150)
    ..edge(node5, node1, curveBend: 700)
    ..node<String, String>(node1, position: const Offset(0.1, 0.3), title: "Start",
        processor: (d, r) => racerProcessor(node1))
    ..node<String, String>(node2, position: const Offset(0.5, 0.2), title: "Process A",
        processor: (d, r) => racerProcessor(node2))
    ..node<String, String>(node3, position: const Offset(0.5, 0.5), title: "Decision",
        processor: (d, r) => racerProcessor(node3))
    ..node<String, String>(node4, position: const Offset(0.8, 0.3), title: "Process B",
        processor: (d, r) => racerProcessor(node4))
    ..node<String, String>(node5, position: const Offset(0.8, 0.7), title: "End",
        processor: (d, r) => racerProcessor(node5));

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
