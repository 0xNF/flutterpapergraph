import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

ControlFlowGraph acrPoolGraph(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  // State that persists across auto-repeat resets
  bool echoPoolCreated = false;
  bool ledPoolCreated = false;
  int runCount = 0;
  final jobsCompleted = <String, int>{};

  // Per-pool idle teardown timers
  Timer? echoIdleTimer;
  Timer? ledIdleTimer;

  // -- Static Node IDs --
  const nodeActionManager = 'start';
  const nodeACR = 'acr';
  const nodeHypervisor = 'hypervisor';

  // -- EchoTest Dynamic IDs --
  const nodePoolEcho = 'pool_echo';
  const nodeE1 = 'worker_e1';
  const nodeE2 = 'worker_e2';
  const edgeDispatchEcho = 'dyn_dispatch_echo';
  const edgeAssignE1 = 'dyn_assign_e1';
  const edgeAssignE2 = 'dyn_assign_e2';
  const edgeResultE1 = 'dyn_result_e1';
  const edgeResultE2 = 'dyn_result_e2';
  const edgeEchoReturn = 'dyn_echo_return';

  // -- LEDSwitch Dynamic IDs --
  const nodePoolLED = 'pool_led';
  const nodeL1 = 'worker_l1';
  const nodeL2 = 'worker_l2';
  const edgeDispatchLED = 'dyn_dispatch_led';
  const edgeAssignL1 = 'dyn_assign_l1';
  const edgeAssignL2 = 'dyn_assign_l2';
  const edgeResultL1 = 'dyn_result_l1';
  const edgeResultL2 = 'dyn_result_l2';
  const edgeLEDReturn = 'dyn_led_return';

  // -- Teardown functions (synchronous — no race conditions) --
  void teardownEchoPool() {
    if (!echoPoolCreated) return;
    echoPoolCreated = false;
    echoIdleTimer = null;
    router.eventBus.emit(NodeFloatingTextEvent(text: Text("EchoTest idle → teardown"), forNodeId: nodeHypervisor));
    router.graph.removeNode(nodeE1);
    router.graph.removeNode(nodeE2);
    router.graph.removeNode(nodePoolEcho);
  }

  void teardownLEDPool() {
    if (!ledPoolCreated) return;
    ledPoolCreated = false;
    ledIdleTimer = null;
    router.eventBus.emit(NodeFloatingTextEvent(text: Text("LEDSwitch idle → teardown"), forNodeId: nodeHypervisor));
    router.graph.removeNode(nodeL1);
    router.graph.removeNode(nodeL2);
    router.graph.removeNode(nodePoolLED);
  }

  // -- Idle timer management --
  void startEchoIdleTimer() {
    echoIdleTimer?.cancel();
    echoIdleTimer = Timer(Duration(seconds: 10), teardownEchoPool);
  }

  void startLedIdleTimer() {
    ledIdleTimer?.cancel();
    ledIdleTimer = Timer(Duration(seconds: 10), teardownLEDPool);
  }

  final builder = GraphBuilder()
    ..startAt(nodeActionManager)
    ..properties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true);

  // -- Static Edges --
  final edgePostRun = builder.edge(nodeActionManager, nodeACR, label: 'POST /run', curveBend: -100, labelOffset: Offset(0, -25));
  final edgeRunRequest = builder.edge(nodeACR, nodeHypervisor, label: 'RunRequest', curveBend: -100, labelOffset: Offset(0, -25));
  final edgeRunResult = builder.edge(nodeHypervisor, nodeACR, label: 'RunResult', curveBend: 150, labelOffset: Offset(0, 20));
  final edgeResponse = builder.edge(nodeACR, nodeActionManager, label: 'HTTP response', curveBend: 150, labelOffset: Offset(0, 20));

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
    );
  }

  // -- Create EchoTest pool infrastructure --
  void createEchoPool(GraphRouter r) {
    final graph = r.graph;

    graph.addEdge(GraphEdgeData(id: edgeDispatchEcho, fromNodeId: nodeHypervisor, toNodeId: nodePoolEcho, label: 'dispatch', curveBend: -80, labelOffset: Offset(-15, -10)));
    graph.addEdge(GraphEdgeData(id: edgeAssignE1, fromNodeId: nodePoolEcho, toNodeId: nodeE1, label: 'assign', curveBend: -60, labelOffset: Offset(0, -20)));
    graph.addEdge(GraphEdgeData(id: edgeAssignE2, fromNodeId: nodePoolEcho, toNodeId: nodeE2, label: 'assign', curveBend: 60, labelOffset: Offset(0, 15)));
    graph.addEdge(GraphEdgeData(id: edgeResultE1, fromNodeId: nodeE1, toNodeId: nodePoolEcho, label: 'result', curveBend: 100, labelOffset: Offset(0, 15)));
    graph.addEdge(GraphEdgeData(id: edgeResultE2, fromNodeId: nodeE2, toNodeId: nodePoolEcho, label: 'result', curveBend: -100, labelOffset: Offset(0, -20)));
    graph.addEdge(GraphEdgeData(id: edgeEchoReturn, fromNodeId: nodePoolEcho, toNodeId: nodeHypervisor, label: 'idle', curveBend: 130, labelOffset: Offset(15, 10)));

    graph.addNode(RoutedGraphNodeData<String, String>(
      id: nodePoolEcho,
      logicalPosition: const Offset(0.55, 0.22),
      contents: NodeContents(stepTitle: "EchoTest\nPool", textStyle: TextStyle(fontSize: 9)),
      nodeState: NodeState.unselected,
      router: r,
      onUpdateState: (o, n) => onUpdateNodeState(nodePoolEcho, o, n, true),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.toEdgeId == edgeDispatchEcho) {
          final e1Jobs = jobsCompleted[nodeE1] ?? 0;
          final e2Jobs = jobsCompleted[nodeE2] ?? 0;
          if (e1Jobs <= e2Jobs) {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ E1 ($e1Jobs jobs)"), forNodeId: nodePoolEcho));
            return RouteDecision(toNodeId: nodeE1, edgeId: edgeAssignE1, label: "assign", data: "assign");
          } else {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ E2 ($e2Jobs jobs)"), forNodeId: nodePoolEcho));
            return RouteDecision(toNodeId: nodeE2, edgeId: edgeAssignE2, label: "assign", data: "assign");
          }
        } else if (d.toEdgeId == edgeResultE1 || d.toEdgeId == edgeResultE2) {
          return RouteDecision(toNodeId: nodeHypervisor, edgeId: edgeEchoReturn, label: "worker idle", data: "done");
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    ));

    graph.addNode(RoutedGraphNodeData<String, String>(
      id: nodeE1,
      logicalPosition: const Offset(0.80, 0.10),
      contents: NodeContents(stepTitle: "Worker E1", textStyle: TextStyle(fontSize: 9)),
      nodeState: NodeState.unselected,
      router: r,
      onUpdateState: (o, n) => onUpdateNodeState(nodeE1, o, n, true),
      processor: (d, r) => workerProcessor(nodeE1, nodePoolEcho, edgeResultE1, d, r),
    ));

    graph.addNode(RoutedGraphNodeData<String, String>(
      id: nodeE2,
      logicalPosition: const Offset(0.80, 0.34),
      contents: NodeContents(stepTitle: "Worker E2", textStyle: TextStyle(fontSize: 9)),
      nodeState: NodeState.unselected,
      router: r,
      onUpdateState: (o, n) => onUpdateNodeState(nodeE2, o, n, true),
      processor: (d, r) => workerProcessor(nodeE2, nodePoolEcho, edgeResultE2, d, r),
    ));

    echoPoolCreated = true;
  }

  // -- Create LEDSwitch pool infrastructure --
  void createLEDPool(GraphRouter r) {
    final graph = r.graph;

    graph.addEdge(GraphEdgeData(id: edgeDispatchLED, fromNodeId: nodeHypervisor, toNodeId: nodePoolLED, label: 'dispatch', curveBend: 80, labelOffset: Offset(15, 10)));
    graph.addEdge(GraphEdgeData(id: edgeAssignL1, fromNodeId: nodePoolLED, toNodeId: nodeL1, label: 'assign', curveBend: 60, labelOffset: Offset(0, -15)));
    graph.addEdge(GraphEdgeData(id: edgeAssignL2, fromNodeId: nodePoolLED, toNodeId: nodeL2, label: 'assign', curveBend: -60, labelOffset: Offset(0, 15)));
    graph.addEdge(GraphEdgeData(id: edgeResultL1, fromNodeId: nodeL1, toNodeId: nodePoolLED, label: 'result', curveBend: -100, labelOffset: Offset(0, -15)));
    graph.addEdge(GraphEdgeData(id: edgeResultL2, fromNodeId: nodeL2, toNodeId: nodePoolLED, label: 'result', curveBend: 100, labelOffset: Offset(0, 15)));
    graph.addEdge(GraphEdgeData(id: edgeLEDReturn, fromNodeId: nodePoolLED, toNodeId: nodeHypervisor, label: 'idle', curveBend: -130, labelOffset: Offset(-15, -10)));

    graph.addNode(RoutedGraphNodeData<String, String>(
      id: nodePoolLED,
      logicalPosition: const Offset(0.55, 0.78),
      contents: NodeContents(stepTitle: "LEDSwitch\nPool", textStyle: TextStyle(fontSize: 9)),
      nodeState: NodeState.unselected,
      router: r,
      onUpdateState: (o, n) => onUpdateNodeState(nodePoolLED, o, n, true),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.toEdgeId == edgeDispatchLED) {
          final l1Jobs = jobsCompleted[nodeL1] ?? 0;
          final l2Jobs = jobsCompleted[nodeL2] ?? 0;
          if (l1Jobs <= l2Jobs) {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ L1 ($l1Jobs jobs)"), forNodeId: nodePoolLED));
            return RouteDecision(toNodeId: nodeL1, edgeId: edgeAssignL1, label: "assign", data: "assign");
          } else {
            r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ L2 ($l2Jobs jobs)"), forNodeId: nodePoolLED));
            return RouteDecision(toNodeId: nodeL2, edgeId: edgeAssignL2, label: "assign", data: "assign");
          }
        } else if (d.toEdgeId == edgeResultL1 || d.toEdgeId == edgeResultL2) {
          return RouteDecision(toNodeId: nodeHypervisor, edgeId: edgeLEDReturn, label: "worker idle", data: "done");
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    ));

    graph.addNode(RoutedGraphNodeData<String, String>(
      id: nodeL1,
      logicalPosition: const Offset(0.80, 0.66),
      contents: NodeContents(stepTitle: "Worker L1", textStyle: TextStyle(fontSize: 9)),
      nodeState: NodeState.unselected,
      router: r,
      onUpdateState: (o, n) => onUpdateNodeState(nodeL1, o, n, true),
      processor: (d, r) => workerProcessor(nodeL1, nodePoolLED, edgeResultL1, d, r),
    ));

    graph.addNode(RoutedGraphNodeData<String, String>(
      id: nodeL2,
      logicalPosition: const Offset(0.80, 0.90),
      contents: NodeContents(stepTitle: "Worker L2", textStyle: TextStyle(fontSize: 9)),
      nodeState: NodeState.unselected,
      router: r,
      onUpdateState: (o, n) => onUpdateNodeState(nodeL2, o, n, true),
      processor: (d, r) => workerProcessor(nodeL2, nodePoolLED, edgeResultL2, d, r),
    ));

    ledPoolCreated = true;
  }

  // -- Static Nodes --
  builder
    // Action Manager — sends POST /run, alternates component type each run
    ..node<String, String>(nodeActionManager, position: const Offset(0.03, 0.5), title: "Action\nManager",
      processor: (d, r) async {
        if (d.fromEdgeId == edgePostRun) {
          await Future.delayed(r.processingDuration);
          final componentType = runCount.isEven ? "EchoTest" : "LEDSwitch";
          runCount++;
          r.eventBus.emit(NodeFloatingTextEvent(text: Text(componentType), forNodeId: nodeActionManager));
          return RouteDecision(toNodeId: nodeACR, edgeId: edgePostRun, label: componentType, data: componentType);
        } else if (d.toEdgeId == edgeResponse) {
          onEnd();
          return RouteDecision.terminal(resultingNodeState: NodeState.unselected);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // ACR — HTTP front-end, forwards to Hypervisor
    ..node<String, String>(nodeACR, position: const Offset(0.15, 0.5), title: "ACR", textStyle: TextStyle(fontSize: 10),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        final data = d.actualData ?? "";
        if (d.toEdgeId == edgePostRun) {
          return RouteDecision(toNodeId: nodeHypervisor, edgeId: edgeRunRequest, label: data, data: data);
        } else if (d.toEdgeId == edgeRunResult) {
          return RouteDecision(toNodeId: nodeActionManager, edgeId: edgeResponse, label: "result (FB)", data: "result");
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Hypervisor — creates pools on demand, manages idle timers
    ..node<String, String>(nodeHypervisor, position: const Offset(0.30, 0.5), title: "Hypervisor", textStyle: TextStyle(fontSize: 10),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        final data = d.actualData ?? "";

        if (d.toEdgeId == edgeRunRequest) {
          if (data == "EchoTest") {
            // Cancel teardown — this pool is being used
            echoIdleTimer?.cancel();
            echoIdleTimer = null;

            if (!echoPoolCreated) {
              r.eventBus.emit(NodeFloatingTextEvent(text: Text("no EchoTest pool → spinning up..."), forNodeId: nodeHypervisor));
              await Future.delayed(r.processingDuration);
              createEchoPool(r);
            } else {
              r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ EchoTest (warm)"), forNodeId: nodeHypervisor));
            }
            return RouteDecision(toNodeId: nodePoolEcho, edgeId: edgeDispatchEcho, label: "EchoTest", data: "EchoTest");
          } else if (data == "LEDSwitch") {
            // Cancel teardown — this pool is being used
            ledIdleTimer?.cancel();
            ledIdleTimer = null;

            if (!ledPoolCreated) {
              r.eventBus.emit(NodeFloatingTextEvent(text: Text("no LEDSwitch pool → spinning up..."), forNodeId: nodeHypervisor));
              await Future.delayed(r.processingDuration);
              createLEDPool(r);
            } else {
              r.eventBus.emit(NodeFloatingTextEvent(text: Text("→ LEDSwitch (warm)"), forNodeId: nodeHypervisor));
            }
            return RouteDecision(toNodeId: nodePoolLED, edgeId: edgeDispatchLED, label: "LEDSwitch", data: "LEDSwitch");
          }
        } else if (d.toEdgeId == edgeEchoReturn) {
          // EchoTest request done — start its idle timer
          startEchoIdleTimer();
          return RouteDecision(toNodeId: nodeACR, edgeId: edgeRunResult, label: "result (FB)", data: "result");
        } else if (d.toEdgeId == edgeLEDReturn) {
          // LEDSwitch request done — start its idle timer
          startLedIdleTimer();
          return RouteDecision(toNodeId: nodeACR, edgeId: edgeRunResult, label: "result (FB)", data: "result");
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    );

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
