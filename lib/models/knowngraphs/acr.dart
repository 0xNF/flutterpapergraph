import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

ControlFlowGraph acrGraph(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
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

  final builder = GraphBuilder()
    ..startAt(nodeHostApp)
    ..properties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true);

  // -- Edges --
  final edgePostRun = builder.edge(nodeHostApp, nodeACR, label: 'POST /run', curveBend: -100, labelOffset: Offset(0, -25));
  final edgeRunRequest = builder.edge(nodeACR, nodeHypervisor, label: 'RunRequest', curveBend: -100, labelOffset: Offset(0, -25));
  final edgeRunResult = builder.edge(nodeHypervisor, nodeACR, label: 'RunResult', curveBend: 150, labelOffset: Offset(0, 20));
  final edgeResponse = builder.edge(nodeACR, nodeHostApp, label: 'HTTP response', curveBend: 150, labelOffset: Offset(0, 20));

  // EchoTest path
  final edgeDispatchEcho = builder.edge(nodeHypervisor, nodePoolEcho, label: 'dispatch', curveBend: -80, labelOffset: Offset(-15, -10));
  final edgeAssignE1 = builder.edge(nodePoolEcho, nodeWorkerE1, label: 'assign', curveBend: -60, labelOffset: Offset(0, -20));
  final edgeAssignE2 = builder.edge(nodePoolEcho, nodeWorkerE2, label: 'assign', curveBend: 60, labelOffset: Offset(0, 15));
  final edgeResultE1 = builder.edge(nodeWorkerE1, nodePoolEcho, label: 'result', curveBend: 100, labelOffset: Offset(0, 15));
  final edgeResultE2 = builder.edge(nodeWorkerE2, nodePoolEcho, label: 'result', curveBend: -100, labelOffset: Offset(0, -20));
  final edgePoolEchoReturn = builder.edge(nodePoolEcho, nodeHypervisor, label: 'idle', curveBend: 130, labelOffset: Offset(15, 10));

  // LEDSwitch path
  final edgeDispatchLED = builder.edge(nodeHypervisor, nodePoolLED, label: 'dispatch', curveBend: 80, labelOffset: Offset(15, 10));
  final edgeAssignL1 = builder.edge(nodePoolLED, nodeWorkerL1, label: 'assign', curveBend: 60, labelOffset: Offset(0, -15));
  final edgeAssignL2 = builder.edge(nodePoolLED, nodeWorkerL2, label: 'assign', curveBend: -60, labelOffset: Offset(0, 15));
  final edgeResultL1 = builder.edge(nodeWorkerL1, nodePoolLED, label: 'result', curveBend: -100, labelOffset: Offset(0, -15));
  final edgeResultL2 = builder.edge(nodeWorkerL2, nodePoolLED, label: 'result', curveBend: 100, labelOffset: Offset(0, 15));
  final edgePoolLEDReturn = builder.edge(nodePoolLED, nodeHypervisor, label: 'idle', curveBend: -130, labelOffset: Offset(-15, -10));

  // -- Worker processor factory --
  Future<RouteDecision> workerProcessor(String workerId, String poolId, String resultEdgeId, DataPacket<String?> d, GraphRouter r) async {
    await Future.delayed(r.processingDuration);
    jobsCompleted[workerId] = (jobsCompleted[workerId] ?? 0) + 1;
    r.eventBus.emit(NodeFloatingTextEvent(text: Text("process()"), forNodeId: workerId));
    return RouteDecision(
      toNodeId: poolId,
      edgeId: resultEdgeId,
      label: "result",
      data: "OutputPayload",
      disableNodeAfter: true,
    );
  }

  // -- Nodes --
  builder
    // Action Manager
    ..node<String, String>(nodeHostApp, position: const Offset(0.03, 0.5), title: "Action\nManager",
      processor: (d, r) async {
        if (d.fromEdgeId == edgePostRun) {
          // Initial trigger — pick a random component type
          final componentType = random.nextBool() ? "EchoTest" : "LEDSwitch";
          await Future.delayed(r.processingDuration);
          return RouteDecision(toNodeId: nodeACR, edgeId: edgePostRun, label: componentType, data: componentType);
        } else if (d.toEdgeId == edgeResponse) {
          onEnd();
          return RouteDecision.terminal(resultingNodeState: NodeState.unselected);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // ACR
    ..node<String, String>(nodeACR, position: const Offset(0.15, 0.5), title: "ACR", textStyle: TextStyle(fontSize: 10),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        final data = d.actualData ?? "";

        if (d.toEdgeId == edgePostRun) {
          return RouteDecision(toNodeId: nodeHypervisor, edgeId: edgeRunRequest, label: data, data: data);
        } else if (d.toEdgeId == edgeRunResult) {
          return RouteDecision(toNodeId: nodeHostApp, edgeId: edgeResponse, label: "result (FB)", data: "result", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Hypervisor
    ..node<String, String>(nodeHypervisor, position: const Offset(0.30, 0.5), title: "Hypervisor", textStyle: TextStyle(fontSize: 10),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        final data = d.actualData ?? "";

        if (d.toEdgeId == edgeRunRequest) {
          if (data == "EchoTest") {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ EchoTest"), forNodeId: nodeHypervisor));
            return RouteDecision(toNodeId: nodePoolEcho, edgeId: edgeDispatchEcho, label: "EchoTest", data: data);
          } else if (data == "LEDSwitch") {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ LEDSwitch"), forNodeId: nodeHypervisor));
            return RouteDecision(toNodeId: nodePoolLED, edgeId: edgeDispatchLED, label: "LEDSwitch", data: data);
          }
        } else if (d.toEdgeId == edgePoolEchoReturn || d.toEdgeId == edgePoolLEDReturn) {
          return RouteDecision(toNodeId: nodeACR, edgeId: edgeRunResult, label: "result (FB)", data: "result", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Pool: EchoTest
    ..node<String, String>(nodePoolEcho, position: const Offset(0.55, 0.22), title: "EchoTest Pool", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);

        if (d.toEdgeId == edgeDispatchEcho) {
          final e1Jobs = jobsCompleted[nodeWorkerE1] ?? 0;
          final e2Jobs = jobsCompleted[nodeWorkerE2] ?? 0;
          if (e1Jobs <= e2Jobs) {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ E1 ($e1Jobs jobs)"), forNodeId: nodePoolEcho));
            return RouteDecision(toNodeId: nodeWorkerE1, edgeId: edgeAssignE1, label: "assign", data: "assign");
          } else {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ E2 ($e2Jobs jobs)"), forNodeId: nodePoolEcho));
            return RouteDecision(toNodeId: nodeWorkerE2, edgeId: edgeAssignE2, label: "assign", data: "assign");
          }
        } else if (d.toEdgeId == edgeResultE1 || d.toEdgeId == edgeResultE2) {
          return RouteDecision(toNodeId: nodeHypervisor, edgeId: edgePoolEchoReturn, label: "worker idle", data: "done", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Pool: LEDSwitch
    ..node<String, String>(nodePoolLED, position: const Offset(0.55, 0.78), title: "LEDSwitch Pool", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);

        if (d.toEdgeId == edgeDispatchLED) {
          final l1Jobs = jobsCompleted[nodeWorkerL1] ?? 0;
          final l2Jobs = jobsCompleted[nodeWorkerL2] ?? 0;
          if (l1Jobs <= l2Jobs) {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ L1 ($l1Jobs jobs)"), forNodeId: nodePoolLED));
            return RouteDecision(toNodeId: nodeWorkerL1, edgeId: edgeAssignL1, label: "assign", data: "assign");
          } else {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ L2 ($l2Jobs jobs)"), forNodeId: nodePoolLED));
            return RouteDecision(toNodeId: nodeWorkerL2, edgeId: edgeAssignL2, label: "assign", data: "assign");
          }
        } else if (d.toEdgeId == edgeResultL1 || d.toEdgeId == edgeResultL2) {
          return RouteDecision(toNodeId: nodeHypervisor, edgeId: edgePoolLEDReturn, label: "worker idle", data: "done", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Workers -- shared factory processor
    ..node<String, String>(nodeWorkerE1, position: const Offset(0.80, 0.10), title: "Worker E1", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) => workerProcessor(nodeWorkerE1, nodePoolEcho, edgeResultE1, d, r),
    )
    ..node<String, String>(nodeWorkerE2, position: const Offset(0.80, 0.34), title: "Worker E2", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) => workerProcessor(nodeWorkerE2, nodePoolEcho, edgeResultE2, d, r),
    )
    ..node<String, String>(nodeWorkerL1, position: const Offset(0.80, 0.66), title: "Worker L1", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) => workerProcessor(nodeWorkerL1, nodePoolLED, edgeResultL1, d, r),
    )
    ..node<String, String>(nodeWorkerL2, position: const Offset(0.80, 0.90), title: "Worker L2", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) => workerProcessor(nodeWorkerL2, nodePoolLED, edgeResultL2, d, r),
    );

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
