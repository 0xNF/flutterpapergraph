import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

ControlFlowGraph racers(GraphFlowController flowController, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  final r = math.Random(DateTime.now().millisecondsSinceEpoch);

  // Create a late-binding that the inner process functions can use
  late final ControlFlowGraph graph;

  Duration selectDurationQuadratic() {
    // Normalize to 0-1
    double normalized = r.nextDouble();

    // Quadratic bias toward median (1000)
    // Creates a peak at 1000
    double biased = 0.5 + (normalized - 0.5) * (1 - (normalized - 0.5).abs());

    // Map to 100-2000 range
    int milliseconds = (100 + biased * 1900).toInt();
    return Duration(milliseconds: milliseconds);
  }

  const node1 = "node1";
  const node2 = "node2";
  const node3 = "node3";
  const node4 = "node4";
  const node5 = "node5";

  graph = ControlFlowGraph(
    startingNodeId: node1,
    properties: GraphProperties(isAutomatic: true, hasEnd: false, hasTuneableTravelTime: false, hasTuneableProcessingTime: false, canShowCurrentState: false, canStepDebug: false),
    nodes: [
      TypedGraphNodeData<String, String>(
        id: node1,
        logicalPosition: const Offset(0.1, 0.3),
        contents: NodeContents(stepTitle: "Start"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(node1, o, n, true),
        processor: (d) async {
          await Future.delayed(selectDurationQuadratic());
          final to = graph.getOutgoingEdges(node1).sample(1).firstWhereOrNull((x) => x.edgeState != EdgeState.disabled)?.toNodeId;
          if (to != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: node1,
                goingToNodeId: to,
                data: DataPacket<String>(labelText: "f1", actualData: "x"),
                duration: selectDurationQuadratic(),
              ),
            );
          }
          return ProcessResult(state: NodeState.selected);
        },
      ),
      TypedGraphNodeData<String, String>(
        id: node2,
        logicalPosition: const Offset(0.5, 0.2),
        contents: NodeContents(stepTitle: "Process A"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(node2, o, n, true),
        processor: (d) async {
          await Future.delayed(selectDurationQuadratic());
          final to = graph.getOutgoingEdges(node2).sample(1).firstWhereOrNull((x) => x.edgeState != EdgeState.disabled)?.toNodeId;
          if (to != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: node2,
                goingToNodeId: to,
                data: DataPacket<String>(labelText: "f2", actualData: "x"),
                duration: selectDurationQuadratic(),
              ),
            );
          }
          return ProcessResult(state: NodeState.selected);
        },
      ),
      TypedGraphNodeData<String, String>(
        id: node3,
        logicalPosition: const Offset(0.5, 0.5),
        contents: NodeContents(stepTitle: "Decision"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(node3, o, n, true),
        processor: (d) async {
          await Future.delayed(selectDurationQuadratic());
          final to = graph.getOutgoingEdges(node3).sample(1).firstWhereOrNull((x) => x.edgeState != EdgeState.disabled)?.toNodeId;
          if (to != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: node3,
                goingToNodeId: to,
                data: DataPacket<String>(labelText: "f3", actualData: "x"),
                duration: selectDurationQuadratic(),
              ),
            );
          }
          return ProcessResult(state: NodeState.selected);
        },
      ),
      TypedGraphNodeData<String, String>(
        id: node4,
        logicalPosition: const Offset(0.8, 0.3),
        contents: NodeContents(stepTitle: "Process B"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(node4, o, n, true),
        processor: (d) async {
          await Future.delayed(selectDurationQuadratic());
          final to = graph.getOutgoingEdges(node4).sample(1).firstWhereOrNull((x) => x.edgeState != EdgeState.disabled)?.toNodeId;
          if (to != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: node4,
                goingToNodeId: to,
                data: DataPacket<String>(labelText: "f4", actualData: "x"),
                duration: selectDurationQuadratic(),
              ),
            );
          }
          return ProcessResult(state: NodeState.selected);
        },
      ),
      TypedGraphNodeData<String, String>(
        id: node5,
        logicalPosition: const Offset(0.8, 0.7),
        contents: NodeContents(stepTitle: "End"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(node5, o, n, true),
        processor: (d) async {
          // throw Exception("Testing Execution Stops");
          await Future.delayed(selectDurationQuadratic());
          final to = graph.getOutgoingEdges(node5).sample(1).firstWhereOrNull((x) => x.edgeState != EdgeState.disabled)?.toNodeId;
          if (to != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: node5,
                goingToNodeId: to,
                data: DataPacket(labelText: "f5", actualData: "x"),
                duration: selectDurationQuadratic(),
              ),
            );
          }
          return ProcessResult(state: NodeState.selected);
        },
      ),
    ],
    edges: [
      GraphEdgeData(id: '0', fromNodeId: node1, toNodeId: node2, label: 'init', curveBend: 500),
      GraphEdgeData(id: '1', fromNodeId: node2, toNodeId: node3, label: 'continue'),
      GraphEdgeData(id: '2', fromNodeId: node3, toNodeId: node4, label: 'yes', curveBend: -200),
      GraphEdgeData(id: '3', fromNodeId: node3, toNodeId: node5, label: 'no', curveBend: 300),
      GraphEdgeData(id: '4', fromNodeId: node4, toNodeId: node5, curveBend: -150),
      GraphEdgeData(id: '5', fromNodeId: node5, toNodeId: node1, curveBend: 700),
    ],
  );

  return graph;
}
