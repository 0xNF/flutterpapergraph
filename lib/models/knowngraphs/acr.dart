import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

ControlFlowGraph acrGraph(GraphFlowController flowController, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  final random = Random();

  // Persists across auto-repeat resets so the pool can track lifetime load
  final jobsCompleted = <String, int>{};

  // -- Node IDs --
  const nodeHostApp = 'start';
  const nodeACR = 'acr';
  const nodeHypervisor = 'hypervisor';
  const nodePoolEcho = 'poolEchoTest';
  const nodePoolLED = 'poolLEDSwitch';
  const nodeWorkerE1 = 'workerE1';
  const nodeWorkerE2 = 'workerE2';
  const nodeWorkerL1 = 'workerL1';
  const nodeWorkerL2 = 'workerL2';

  // -- Shared edges (reused every run) --
  const edgePostRun = "0_initiate";        // ActionManager → ACR
  const edgeRunRequest = "1_run_request";   // ACR → Hypervisor
  const edgeRunResult = "2_run_result";     // Hypervisor → ACR
  const edgeResponse = "3_response";        // ACR → ActionManager

  // -- EchoTest edges --
  const edgeDispatchEcho = "4_dispatch_echo";
  const edgeAssignE1 = "5_assign_e1";
  const edgeAssignE2 = "6_assign_e2";
  const edgeResultE1 = "7_result_e1";
  const edgeResultE2 = "8_result_e2";
  const edgePoolEchoReturn = "9_pool_echo_return";

  // -- LEDSwitch edges --
  const edgeDispatchLED = "10_dispatch_led";
  const edgeAssignL1 = "11_assign_l1";
  const edgeAssignL2 = "12_assign_l2";
  const edgeResultL1 = "13_result_l1";
  const edgeResultL2 = "14_result_l2";
  const edgePoolLEDReturn = "15_pool_led_return";

  late final ControlFlowGraph graph;
  graph = ControlFlowGraph(
    startingNodeId: nodeHostApp,
    properties: GraphProperties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true, canShowCurrentState: false, canStepDebug: false),
    nodes: [
      // ==================== Action Manager ====================
      TypedGraphNodeData<String, String>(
        id: nodeHostApp,
        logicalPosition: const Offset(0.03, 0.5),
        contents: NodeContents(stepTitle: "Action\nManager"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeHostApp, o, n, true),
        processor: (d) async {
          const nid = nodeHostApp;

          if (d.fromEdgeId == edgePostRun) {
            // Initial trigger — pick a random component type
            final componentType = random.nextBool() ? "EchoTest" : "LEDSwitch";

            await Future.delayed(InheritedGraphConfigSettings.of(fnGetBuildContext()).stepSettings.processingDuration);

            final edge = graph.edges.firstWhereOrNull((x) => x.id == edgePostRun && x.edgeState != EdgeState.disabled);
            if (edge != null) {
              flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: nodeACR,
                  edgeId: edgePostRun,
                  data: DataPacket<String>(labelText: componentType, actualData: componentType, fromNodeId: nid, toNodeId: nodeACR, toEdgeId: edge.id),
                  disableEdgeAfter: true,
                  disableNodeAfter: false,
                  duration: InheritedGraphConfigSettings.of(fnGetBuildContext()).stepSettings.travelDuration,
                ),
              );
            }
            return ProcessResult(state: NodeState.selected);
          } else if (d.toEdgeId == edgeResponse) {
            // Request complete
            onEnd();
            return ProcessResult(state: NodeState.unselected);
          }

          return ProcessResult(state: NodeState.selected);
        },
      ),

      // ==================== ACR ====================
      TypedGraphNodeData<String, String>(
        id: nodeACR,
        logicalPosition: const Offset(0.15, 0.5),
        contents: NodeContents(stepTitle: "ACR", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeACR, o, n, true),
        processor: (d) async {
          const nid = nodeACR;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String label = "";
          String data = d.actualData ?? "";
          bool disableNodeAfter = false;

          if (d.toEdgeId == edgePostRun) {
            toNodeId = nodeHypervisor;
            edgeId = edgeRunRequest;
            label = data;
          } else if (d.toEdgeId == edgeRunResult) {
            toNodeId = nodeHostApp;
            edgeId = edgeResponse;
            label = "result (FB)";
            disableNodeAfter = true;
          }

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: label, actualData: data, fromNodeId: nid, toNodeId: toNodeId, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true,
                disableNodeAfter: disableNodeAfter,
              ),
            );
          }
          return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
        },
      ),

      // ==================== Hypervisor ====================
      TypedGraphNodeData<String, String>(
        id: nodeHypervisor,
        logicalPosition: const Offset(0.30, 0.5),
        contents: NodeContents(stepTitle: "Hypervisor", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeHypervisor, o, n, true),
        processor: (d) async {
          const nid = nodeHypervisor;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String label = "";
          String data = d.actualData ?? "";

          if (d.toEdgeId == edgeRunRequest) {
            if (d.actualData == "EchoTest") {
              toNodeId = nodePoolEcho;
              edgeId = edgeDispatchEcho;
              label = "EchoTest";
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("→ EchoTest"), forNodeId: nid));
            } else if (d.actualData == "LEDSwitch") {
              toNodeId = nodePoolLED;
              edgeId = edgeDispatchLED;
              label = "LEDSwitch";
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("→ LEDSwitch"), forNodeId: nid));
            }
          } else if (d.toEdgeId == edgePoolEchoReturn || d.toEdgeId == edgePoolLEDReturn) {
            toNodeId = nodeACR;
            edgeId = edgeRunResult;
            data = "result";
            label = "result (FB)";
          }

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: label, actualData: data, fromNodeId: nid, toNodeId: toNodeId, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true,
                disableNodeAfter: d.toEdgeId == edgePoolEchoReturn || d.toEdgeId == edgePoolLEDReturn,
              ),
            );
          }
          return ProcessResult(state: (d.toEdgeId == edgePoolEchoReturn || d.toEdgeId == edgePoolLEDReturn) ? NodeState.disabled : NodeState.selected);
        },
      ),

      // ==================== Pool: EchoTest ====================
      TypedGraphNodeData<String, String>(
        id: nodePoolEcho,
        logicalPosition: const Offset(0.55, 0.22),
        contents: NodeContents(stepTitle: "EchoTest Pool", textStyle: TextStyle(fontSize: 9)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodePoolEcho, o, n, true),
        processor: (d) async {
          const nid = nodePoolEcho;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String label = "";
          String data = "";
          bool disableNodeAfter = false;

          if (d.toEdgeId == edgeDispatchEcho) {
            // Pick the least-busy worker
            final e1Jobs = jobsCompleted[nodeWorkerE1] ?? 0;
            final e2Jobs = jobsCompleted[nodeWorkerE2] ?? 0;
            if (e1Jobs <= e2Jobs) {
              toNodeId = nodeWorkerE1;
              edgeId = edgeAssignE1;
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("→ E1 ($e1Jobs jobs)"), forNodeId: nid));
            } else {
              toNodeId = nodeWorkerE2;
              edgeId = edgeAssignE2;
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("→ E2 ($e2Jobs jobs)"), forNodeId: nid));
            }
            data = "assign";
            label = "assign";
          } else if (d.toEdgeId == edgeResultE1 || d.toEdgeId == edgeResultE2) {
            toNodeId = nodeHypervisor;
            edgeId = edgePoolEchoReturn;
            data = "done";
            label = "worker idle";
            disableNodeAfter = true;
          }

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: label, actualData: data, fromNodeId: nid, toNodeId: toNodeId, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true,
                disableNodeAfter: disableNodeAfter,
              ),
            );
          }
          return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
        },
      ),

      // ==================== Pool: LEDSwitch ====================
      TypedGraphNodeData<String, String>(
        id: nodePoolLED,
        logicalPosition: const Offset(0.55, 0.78),
        contents: NodeContents(stepTitle: "LEDSwitch Pool", textStyle: TextStyle(fontSize: 9)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodePoolLED, o, n, true),
        processor: (d) async {
          const nid = nodePoolLED;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String label = "";
          String data = "";
          bool disableNodeAfter = false;

          if (d.toEdgeId == edgeDispatchLED) {
            // Pick the least-busy worker
            final l1Jobs = jobsCompleted[nodeWorkerL1] ?? 0;
            final l2Jobs = jobsCompleted[nodeWorkerL2] ?? 0;
            if (l1Jobs <= l2Jobs) {
              toNodeId = nodeWorkerL1;
              edgeId = edgeAssignL1;
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("→ L1 ($l1Jobs jobs)"), forNodeId: nid));
            } else {
              toNodeId = nodeWorkerL2;
              edgeId = edgeAssignL2;
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("→ L2 ($l2Jobs jobs)"), forNodeId: nid));
            }
            data = "assign";
            label = "assign";
          } else if (d.toEdgeId == edgeResultL1 || d.toEdgeId == edgeResultL2) {
            toNodeId = nodeHypervisor;
            edgeId = edgePoolLEDReturn;
            data = "done";
            label = "worker idle";
            disableNodeAfter = true;
          }

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: label, actualData: data, fromNodeId: nid, toNodeId: toNodeId, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true,
                disableNodeAfter: disableNodeAfter,
              ),
            );
          }
          return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
        },
      ),

      // ==================== Worker E1 ====================
      TypedGraphNodeData<String, String>(
        id: nodeWorkerE1,
        logicalPosition: const Offset(0.80, 0.10),
        contents: NodeContents(stepTitle: "Worker E1", textStyle: TextStyle(fontSize: 9)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeWorkerE1, o, n, true),
        processor: (d) async {
          const nid = nodeWorkerE1;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          jobsCompleted[nid] = (jobsCompleted[nid] ?? 0) + 1;
          flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("process()"), forNodeId: nid));

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeResultE1 && x.edgeState != EdgeState.disabled);
          if (edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid, goingToNodeId: nodePoolEcho, edgeId: edgeResultE1,
                data: DataPacket<String>(labelText: "result", actualData: "OutputPayload", fromNodeId: nid, toNodeId: nodePoolEcho, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true, disableNodeAfter: true,
              ),
            );
          }
          return ProcessResult(state: NodeState.disabled);
        },
      ),

      // ==================== Worker E2 ====================
      TypedGraphNodeData<String, String>(
        id: nodeWorkerE2,
        logicalPosition: const Offset(0.80, 0.34),
        contents: NodeContents(stepTitle: "Worker E2", textStyle: TextStyle(fontSize: 9)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeWorkerE2, o, n, true),
        processor: (d) async {
          const nid = nodeWorkerE2;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          jobsCompleted[nid] = (jobsCompleted[nid] ?? 0) + 1;
          flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("process()"), forNodeId: nid));

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeResultE2 && x.edgeState != EdgeState.disabled);
          if (edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid, goingToNodeId: nodePoolEcho, edgeId: edgeResultE2,
                data: DataPacket<String>(labelText: "result", actualData: "OutputPayload", fromNodeId: nid, toNodeId: nodePoolEcho, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true, disableNodeAfter: true,
              ),
            );
          }
          return ProcessResult(state: NodeState.disabled);
        },
      ),

      // ==================== Worker L1 ====================
      TypedGraphNodeData<String, String>(
        id: nodeWorkerL1,
        logicalPosition: const Offset(0.80, 0.66),
        contents: NodeContents(stepTitle: "Worker L1", textStyle: TextStyle(fontSize: 9)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeWorkerL1, o, n, true),
        processor: (d) async {
          const nid = nodeWorkerL1;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          jobsCompleted[nid] = (jobsCompleted[nid] ?? 0) + 1;
          flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("process()"), forNodeId: nid));

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeResultL1 && x.edgeState != EdgeState.disabled);
          if (edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid, goingToNodeId: nodePoolLED, edgeId: edgeResultL1,
                data: DataPacket<String>(labelText: "result", actualData: "OutputPayload", fromNodeId: nid, toNodeId: nodePoolLED, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true, disableNodeAfter: true,
              ),
            );
          }
          return ProcessResult(state: NodeState.disabled);
        },
      ),

      // ==================== Worker L2 ====================
      TypedGraphNodeData<String, String>(
        id: nodeWorkerL2,
        logicalPosition: const Offset(0.80, 0.90),
        contents: NodeContents(stepTitle: "Worker L2", textStyle: TextStyle(fontSize: 9)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeWorkerL2, o, n, true),
        processor: (d) async {
          const nid = nodeWorkerL2;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          jobsCompleted[nid] = (jobsCompleted[nid] ?? 0) + 1;
          flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("process()"), forNodeId: nid));

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeResultL2 && x.edgeState != EdgeState.disabled);
          if (edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid, goingToNodeId: nodePoolLED, edgeId: edgeResultL2,
                data: DataPacket<String>(labelText: "result", actualData: "OutputPayload", fromNodeId: nid, toNodeId: nodePoolLED, toEdgeId: edge.id),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: true, disableNodeAfter: true,
              ),
            );
          }
          return ProcessResult(state: NodeState.disabled);
        },
      ),
    ],
    edges: [
      // === Shared: ActionManager ↔ ACR ↔ Hypervisor ===
      GraphEdgeData(id: edgePostRun, fromNodeId: nodeHostApp, toNodeId: nodeACR, label: 'POST /run', curveBend: -100, labelOffset: Offset(0, -25)),
      GraphEdgeData(id: edgeRunRequest, fromNodeId: nodeACR, toNodeId: nodeHypervisor, label: 'RunRequest', curveBend: -100, labelOffset: Offset(0, -25)),
      GraphEdgeData(id: edgeRunResult, fromNodeId: nodeHypervisor, toNodeId: nodeACR, label: 'RunResult', curveBend: 150, labelOffset: Offset(0, 20)),
      GraphEdgeData(id: edgeResponse, fromNodeId: nodeACR, toNodeId: nodeHostApp, label: 'HTTP response', curveBend: 150, labelOffset: Offset(0, 20)),

      // === EchoTest path ===
      GraphEdgeData(id: edgeDispatchEcho, fromNodeId: nodeHypervisor, toNodeId: nodePoolEcho, label: 'dispatch', curveBend: -80, labelOffset: Offset(-15, -10)),
      GraphEdgeData(id: edgeAssignE1, fromNodeId: nodePoolEcho, toNodeId: nodeWorkerE1, label: 'assign', curveBend: -60, labelOffset: Offset(0, -20)),
      GraphEdgeData(id: edgeAssignE2, fromNodeId: nodePoolEcho, toNodeId: nodeWorkerE2, label: 'assign', curveBend: 60, labelOffset: Offset(0, 15)),
      GraphEdgeData(id: edgeResultE1, fromNodeId: nodeWorkerE1, toNodeId: nodePoolEcho, label: 'result', curveBend: 100, labelOffset: Offset(0, 15)),
      GraphEdgeData(id: edgeResultE2, fromNodeId: nodeWorkerE2, toNodeId: nodePoolEcho, label: 'result', curveBend: -100, labelOffset: Offset(0, -20)),
      GraphEdgeData(id: edgePoolEchoReturn, fromNodeId: nodePoolEcho, toNodeId: nodeHypervisor, label: 'idle', curveBend: 130, labelOffset: Offset(15, 10)),

      // === LEDSwitch path ===
      GraphEdgeData(id: edgeDispatchLED, fromNodeId: nodeHypervisor, toNodeId: nodePoolLED, label: 'dispatch', curveBend: 80, labelOffset: Offset(15, 10)),
      GraphEdgeData(id: edgeAssignL1, fromNodeId: nodePoolLED, toNodeId: nodeWorkerL1, label: 'assign', curveBend: 60, labelOffset: Offset(0, -15)),
      GraphEdgeData(id: edgeAssignL2, fromNodeId: nodePoolLED, toNodeId: nodeWorkerL2, label: 'assign', curveBend: -60, labelOffset: Offset(0, 15)),
      GraphEdgeData(id: edgeResultL1, fromNodeId: nodeWorkerL1, toNodeId: nodePoolLED, label: 'result', curveBend: -100, labelOffset: Offset(0, -15)),
      GraphEdgeData(id: edgeResultL2, fromNodeId: nodeWorkerL2, toNodeId: nodePoolLED, label: 'result', curveBend: 100, labelOffset: Offset(0, 15)),
      GraphEdgeData(id: edgePoolLEDReturn, fromNodeId: nodePoolLED, toNodeId: nodeHypervisor, label: 'idle', curveBend: -130, labelOffset: Offset(-15, -10)),
    ],
  );

  return graph;
}
