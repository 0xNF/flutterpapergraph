import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

ControlFlowGraph simpleAuthGraph1(GraphFlowController flowController, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  const nodeUser = 'user';
  const nodeSomeSite = 'somesite.com';
  const nodeInstagram = 'instagram';

  const edgeStart = "0_initiate";
  const edgeRedirect = "1_redirect";
  const edgeConfirmLogin = "2_confirm_login";
  const edgeLoginConfirmed = "3_login_confirmed";
  const edgeConfirmPermissions = "4_confirm_permissions";
  const edgePermissionsConfrimed = "5_permissions_confirmed";
  const edgeOk = "6_ok";
  // Create a late-binding that the inner process functions can use
  late final ControlFlowGraph graph;
  graph = ControlFlowGraph(
    startingNodeId: nodeUser,
    properties: GraphProperties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true, canShowCurrentState: false, canStepDebug: false),
    nodes: [
      TypedGraphNodeData<String, String>(
        id: nodeUser,
        logicalPosition: const Offset(0.1, 0.3),
        contents: NodeContents(stepTitle: "User"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeUser, o, n, true),
        processor: (d) async {
          const nid = nodeUser;
          String toNodeId = "";
          String edgeId = "";
          String label = "";
          String data = "";
          bool disbaleEdgeAfter = true;
          bool disableNodeAfter = false;

          if (d == edgeStart) {
            toNodeId = nodeSomeSite;
            edgeId = d!;
            data = d;
            label = "start";
          } else if (d == edgeConfirmLogin || d == edgeConfirmPermissions) {
            toNodeId = nodeInstagram;
            if (d == edgeConfirmLogin) {
              await Future.delayed(Duration(seconds: 2));
              final completer = Completer<String>(); // will show a random username
              flowController.dataFlowEventBus.emit(ShowWidgetOverlayEvent(widget: Text("Whats up"), completer: completer, forNodeId: nid));
              final username = await completer.future;
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text(username), forNodeId: nid));
              edgeId = edgeLoginConfirmed;
              data = edgeLoginConfirmed;
              label = "login confirmed";
            } else if (d == edgeConfirmPermissions) {
              edgeId = edgePermissionsConfrimed;
              data = edgePermissionsConfrimed;
              label = "permissions confirmed";
              disableNodeAfter = true;
            }
          }

          await Future.delayed(InheritedGraphConfigSettings.of(fnGetBuildContext()).stepSettings.processingDuration);

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: label, actualData: data),
                disableEdgeAfter: disbaleEdgeAfter,
                disableNodeAfter: disableNodeAfter,
                duration: InheritedGraphConfigSettings.of(fnGetBuildContext()).stepSettings.travelDuration,
              ),
            );
          }
          return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
        },
      ),
      TypedGraphNodeData<String, String>(
        id: nodeSomeSite,
        logicalPosition: const Offset(0.5, 0.2),
        contents: NodeContents(stepTitle: "SomeSite.com", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeSomeSite, o, n, true),
        processor: (d) async {
          const nid = nodeSomeSite;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String data = "";
          bool disableEdgeAfter = true;
          bool disableNodeAfter = false;
          if (d == edgeStart) {
            toNodeId = nodeInstagram;
            edgeId = edgeRedirect;
            data = edgeId;
          } else if (d == edgeOk) {
            disableNodeAfter = true;
            // this is the last in the sequence, trigger the OnEnd callback
            onEnd();
            return ProcessResult(state: NodeState.unselected);
          } else {
            return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
          }

          final ctx2 = fnGetBuildContext();

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: "redirecting", actualData: data),
                duration: InheritedGraphConfigSettings.of(ctx2).stepSettings.travelDuration,
                disableEdgeAfter: disableEdgeAfter,
                disableNodeAfter: disableNodeAfter,
              ),
            );
          }
          return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
        },
      ),
      TypedGraphNodeData<String, String>(
        id: 'instagram',
        logicalPosition: const Offset(0.8, 0.3),
        contents: NodeContents(stepTitle: "instagram", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeInstagram, o, n, true),
        processor: (d) async {
          const nid = nodeInstagram;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = nodeUser;
          String edgeId = "";
          String label = "";
          String data = "";
          bool disableEdgeAfter = true;
          bool disableNodeAfter = false;
          if (d == edgeRedirect) {
            edgeId = edgeConfirmLogin;
            data = edgeConfirmLogin;
            label = "login";
          } else if (d == edgeLoginConfirmed) {
            edgeId = edgeConfirmPermissions;
            data = edgeConfirmPermissions;
            label = "authorize";
          } else if (d == edgePermissionsConfrimed) {
            toNodeId = nodeSomeSite;
            edgeId = edgeOk;
            data = edgeOk;
            label = "permissions confirmed";
            disableNodeAfter = true;
          }

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(labelText: label, actualData: data),
                duration: InheritedGraphConfigSettings.of(ctx).stepSettings.travelDuration,
                disableEdgeAfter: disableEdgeAfter,
                disableNodeAfter: disableNodeAfter,
              ),
            );
          }
          return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
        },
      ),
    ],
    edges: [
      GraphEdgeData(id: edgeStart, fromNodeId: nodeUser, toNodeId: nodeSomeSite, label: '1) initiate', curveBend: -100, labelOffset: Offset(0, -25)),
      GraphEdgeData(id: edgeRedirect, fromNodeId: nodeSomeSite, toNodeId: nodeInstagram, label: '2) redirect', curveBend: 100, labelOffset: Offset(0, -20)),
      GraphEdgeData(id: edgeConfirmLogin, fromNodeId: nodeInstagram, toNodeId: nodeUser, label: '3) confirm login', curveBend: 200, labelOffset: Offset(0, 20)),
      GraphEdgeData(id: edgeLoginConfirmed, fromNodeId: nodeUser, toNodeId: nodeInstagram, label: '4) login confirmed', curveBend: 300, labelOffset: Offset(0, 20)),
      GraphEdgeData(id: edgeConfirmPermissions, fromNodeId: nodeInstagram, toNodeId: nodeUser, label: '5) check permissions', curveBend: 450, labelOffset: Offset(0, -20)),
      GraphEdgeData(id: edgePermissionsConfrimed, fromNodeId: nodeUser, toNodeId: nodeInstagram, label: '6) permisssions confirmed', curveBend: 700, labelOffset: Offset(0, -20)),
      GraphEdgeData(id: edgeOk, fromNodeId: nodeInstagram, toNodeId: nodeSomeSite, label: '7) ok', curveBend: -150, labelOffset: Offset(0, 20)),
    ],
  );

  return graph;
}
