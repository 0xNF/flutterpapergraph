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
  const nodeApplication = 'application';
  const nodeSomeSite = 'somesite.com';
  const nodeInstagramAuthServer = 'instagramAuthServer';
  const nodeInstagramAPIServer = 'instagramAPIServer';

  const edgeStart = "0_initiate";
  const edgeReturnAccessToken = "1_redirect";
  const edgePassAccessToken = "2_confirm_login";
  const edgeReturnAPIResult = "3_login_confirmed";
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

          if (d == edgeStart) {
            toNodeId = nodeSomeSite;
            edgeId = d!;
            data = d;
            label = "start";
          } else if (d == edgePassAccessToken) {
            toNodeId = nodeInstagramAuthServer;
            if (d == edgePassAccessToken) {
              final username = "oauthuser@home.arpa";
              final completer = Completer<String>();
              flowController.dataFlowEventBus.emit(
                ShowWidgetOverlayEvent(
                  widget: LoginWidget(
                    onConfirm: () => completer.complete(username),
                    onCancel: () async {},
                    siteName: "somesite",
                    loginUser: LoginUser(username: username, password: "lmaolol"),
                    textEntryDuration: InheritedGraphConfigSettings.of(fnGetBuildContext()).stepSettings.processingDuration,
                  ),

                  completer: completer,
                  forNodeId: nid,
                ),
              );
              await completer.future;
              flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text(username), forNodeId: nid));
              edgeId = edgeReturnAPIResult;
              data = edgeReturnAPIResult;
              label = "login confirmed";
            }
            // else if (d == edgeConfirmPermissions) {
            //   final client = OAuthClient(clientId: "1234", name: "somesite.com", redirectUri: "somesite.com/cb/rdr", scopes: ["scope1", "offline_access", "read_all_stuff"]);
            //   final completer = Completer<String>();
            //   flowController.dataFlowEventBus.emit(
            //     ShowWidgetOverlayEvent(
            //       widget: AuthorizeOAuthClientWidget(
            //         onConfirm: () => completer.complete(client.name),
            //         onCancel: () async {},
            //         oauthClient: client,
            //       ),

            //       completer: completer,
            //       forNodeId: nid,
            //     ),
            //   );
            //   await completer.future;
            //   flowController.dataFlowEventBus.emit(NodeFloatingTextEvent(text: Text("granted: ${client.name}"), forNodeId: nid));
            //   edgeId = edgePermissionsConfrimed;
            //   data = edgePermissionsConfrimed;
            //   label = "permissions confirmed";
            //   disableNodeAfter = true;
            // }
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
        id: nodeInstagramAuthServer,
        logicalPosition: const Offset(0.8, 0.2),
        contents: NodeContents(stepTitle: "Auth Server", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeInstagramAuthServer, o, n, true),
        processor: (d) async {
          const nid = nodeInstagramAuthServer;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = "";
          String edgeId = "";
          String data = "";
          bool disableEdgeAfter = true;
          bool disableNodeAfter = false;
          if (d == edgeStart) {
            toNodeId = nodeInstagramAuthServer;
            edgeId = edgeReturnAccessToken;
            data = edgeId;
          }
          // else if (d == edgeOk) {
          //   disableNodeAfter = true;
          //   // this is the last in the sequence, trigger the OnEnd callback
          //   onEnd();
          //   return ProcessResult(state: NodeState.unselected);
          // }
          else {
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
        id: nodeInstagramAPIServer,
        logicalPosition: const Offset(0.8, 0.8),
        contents: NodeContents(stepTitle: "API Server", textStyle: TextStyle(fontSize: 10)),
        nodeState: NodeState.unselected,
        onUpdateState: (o, n) => onUpdateNodeState(nodeInstagramAuthServer, o, n, true),
        processor: (d) async {
          const nid = nodeInstagramAuthServer;
          BuildContext ctx = fnGetBuildContext();
          await Future.delayed(InheritedGraphConfigSettings.of(ctx).stepSettings.processingDuration);
          ctx = fnGetBuildContext();
          String toNodeId = nodeApplication;
          String edgeId = "";
          String label = "";
          String data = "";
          bool disableEdgeAfter = true;
          bool disableNodeAfter = false;
          if (d == edgeReturnAccessToken) {
            edgeId = edgePassAccessToken;
            data = edgePassAccessToken;
            label = "login";
          }
          // else if (d == edgeReturnAPIResult) {
          //   edgeId = edgeConfirmPermissions;
          //   data = edgeConfirmPermissions;
          //   label = "authorize";
          // } else if (d == edgePermissionsConfrimed) {
          //   toNodeId = nodeSomeSite;
          //   edgeId = edgeOk;
          //   data = edgeOk;
          //   label = "permissions confirmed";
          //   disableNodeAfter = true;
          // }

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
      GraphEdgeData(id: edgeStart, fromNodeId: nodeApplication, toNodeId: nodeInstagramAuthServer, label: 'Auth Request', curveBend: -100, labelOffset: Offset(0, -25)),
      GraphEdgeData(id: edgeReturnAccessToken, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeApplication, label: 'Access Token', curveBend: 300, labelOffset: Offset(0, -20)),
      // GraphEdgeData(id: edgeConfirmLogin, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeUser, label: '3) confirm login', curveBend: 200, labelOffset: Offset(0, 20)),
      // GraphEdgeData(id: edgeLoginConfirmed, fromNodeId: nodeUser, toNodeId: nodeInstagramAuthServer, label: '4) login confirmed', curveBend: 300, labelOffset: Offset(0, 20)),
      // GraphEdgeData(id: edgeConfirmPermissions, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeUser, label: '5) check permissions', curveBend: 450, labelOffset: Offset(0, -20)),
      // GraphEdgeData(id: edgePermissionsConfrimed, fromNodeId: nodeUser, toNodeId: nodeInstagramAuthServer, label: '6) permisssions confirmed', curveBend: 700, labelOffset: Offset(0, -20)),
      // GraphEdgeData(id: edgeOk, fromNodeId: nodeInstagramAuthServer, toNodeId: nodeSomeSite, label: '7) ok', curveBend: -150, labelOffset: Offset(0, 20)),
    ],
  );

  return graph;
}
