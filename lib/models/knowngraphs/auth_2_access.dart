import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/models/oauth/oauthclient.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/misc/authwidget.dart';
import 'package:oauthclient/widgets/misc/loginwidget.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

ControlFlowGraph authGraph2AccessToken(GraphFlowController flowController, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  const nodeApplication = 'start';
  const nodeAuthServer = 'instagramAuthServer';
  const nodeAPIServer = 'instagramAPIServer';

  const edgeStart = "0_initiate";
  const edgeReturnAccessToken = "1_return_token";
  const edgePassAccessToken = "2_use_token";
  const edgeReturnAPIResult = "3_return_api_result";
  // Create a late-binding that the inner process functions can use
  late final ControlFlowGraph graph;
  graph = ControlFlowGraph(
    startingNodeId: nodeApplication,
    properties: GraphProperties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true, canShowCurrentState: false, canStepDebug: false),
    nodes: [
      TypedGraphNodeData<String, String>(
        id: nodeApplication,
        logicalPosition: const Offset(0.1, 0.2),
        contents: NodeContents(stepTitle: "Application"),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeApplication, o, n, true),
        processor: (d) async {
          const nid = nodeApplication;
          String toNodeId = "";
          String edgeId = "";
          String label = "";
          String data = "";
          bool disbaleEdgeAfter = true;
          bool disableNodeAfter = false;

          if (d.fromEdgeId == edgeStart) {
            toNodeId = nodeAuthServer;
            edgeId = d.fromEdgeId ?? "";
            data = d.actualData ?? "";
            label = "start";
          } else if (d.toEdgeId == edgeReturnAccessToken || d.toEdgeId == edgeReturnAPIResult) {
            toNodeId = nodeAPIServer;
            edgeId = edgePassAccessToken;
            data = d.toEdgeId == edgeReturnAPIResult ? 'API requst' : "access token received";
            disableNodeAfter = false;
            disbaleEdgeAfter = false;
            label = "bearer: xyz";
          }

          await Future.delayed(InheritedGraphConfigSettings.of(fnGetBuildContext()).stepSettings.processingDuration);

          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(
                  labelText: label,
                  actualData: data,
                  toEdgeId: edge.id,
                  toNodeId: toNodeId,
                  fromNodeId: nid,
                ),
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
        id: nodeAuthServer,
        logicalPosition: const Offset(0.8, 0.2),
        contents: NodeContents(stepTitle: "Auth Server", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeAuthServer, o, n, true),
        processor: (d) async {
          const nid = nodeAuthServer;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String data = "";
          bool disableEdgeAfter = true;
          bool disableNodeAfter = false;
          if (d.toEdgeId == edgeStart) {
            toNodeId = nodeApplication;
            edgeId = edgeReturnAccessToken;
            data = "Authoriation successful";
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
                data: DataPacket<String>(
                  labelText: "access_token",
                  actualData: data,
                  fromNodeId: nid,
                  toEdgeId: edge.id,
                  toNodeId: nid,
                ),
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
        id: nodeAPIServer,
        logicalPosition: const Offset(0.8, 0.8),
        contents: NodeContents(stepTitle: "API Server", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeAPIServer, o, n, true),
        processor: (d) async {
          const nid = nodeAPIServer;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = nodeApplication;
          String edgeId = "";
          String label = "";
          String data = "";
          bool disableEdgeAfter = true;
          bool disableNodeAfter = false;
          if (d.toEdgeId == edgePassAccessToken) {
            edgeId = edgeReturnAPIResult;
            data = "access token is vaid";
            label = "data";
            disableEdgeAfter = false;
            disableNodeAfter = false;
          }
          final edge = graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
          if (toNodeId.isNotEmpty && edge != null) {
            flowController.dataFlowEventBus.emit(
              DataExitedEvent(
                cameFromNodeId: nid,
                goingToNodeId: toNodeId,
                edgeId: edgeId,
                data: DataPacket<String>(
                  labelText: label,
                  actualData: data,
                  toEdgeId: edge.id,
                  fromNodeId: nid,
                  toNodeId: toNodeId,
                ),
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
      GraphEdgeData(id: edgeStart, fromNodeId: nodeApplication, toNodeId: nodeAuthServer, label: 'Auth Request\n{ClientId, Scope, GrantType}', curveBend: -100, labelOffset: Offset(0, -25)),
      GraphEdgeData(id: edgeReturnAccessToken, fromNodeId: nodeAuthServer, toNodeId: nodeApplication, label: 'Access Token', curveBend: 200, labelOffset: Offset(0, -20)),
      GraphEdgeData(id: edgePassAccessToken, fromNodeId: nodeApplication, toNodeId: nodeAPIServer, label: 'API Call', curveBend: 600, labelOffset: Offset(0, -30)),
      GraphEdgeData(id: edgeReturnAPIResult, fromNodeId: nodeAPIServer, toNodeId: nodeApplication, label: 'API Result', curveBend: 200, labelOffset: Offset(0, -20)),

      // GraphEdgeData(id: edgeConfirmLogin, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeUser, label: '3) confirm login', curveBend: 200, labelOffset: Offset(0, 20)),
      // GraphEdgeData(id: edgeLoginConfirmed, fromNodeId: nodeUser, toNodeId: nodeInstagramAuthServer, label: '4) login confirmed', curveBend: 300, labelOffset: Offset(0, 20)),
      // GraphEdgeData(id: edgeConfirmPermissions, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeUser, label: '5) check permissions', curveBend: 450, labelOffset: Offset(0, -20)),
      // GraphEdgeData(id: edgePermissionsConfrimed, fromNodeId: nodeUser, toNodeId: nodeInstagramAuthServer, label: '6) permisssions confirmed', curveBend: 700, labelOffset: Offset(0, -20)),
      // GraphEdgeData(id: edgeOk, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeSomeSite, label: '7) ok', curveBend: -150, labelOffset: Offset(0, 20)),
    ],
  );

  return graph;
}
