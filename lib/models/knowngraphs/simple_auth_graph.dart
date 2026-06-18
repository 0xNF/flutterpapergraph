import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/graph/interceptor.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/models/oauth/oauthclient.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/misc/authwidget.dart';
import 'package:oauthclient/widgets/misc/loginwidget.dart';

ControlFlowGraph simpleAuthGraph1(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  const nodeUser = 'user';
  const nodeSomeSite = 'somesite.com';
  const nodeInstagram = 'instagram';

  // Edge IDs needed by interceptors
  const edgeConfirmLogin = 'confirm_login';
  const edgeConfirmPermissions = 'confirm_permissions';

  final builder = GraphBuilder()
    ..startAt(nodeUser)
    ..properties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true);

  // Edges
  final edgeStart = builder.edge(nodeUser, nodeSomeSite, label: '1) initiate', curveBend: -100, labelOffset: Offset(0, -25));
  final edgeRedirect = builder.edge(nodeSomeSite, nodeInstagram, label: '2) redirect', curveBend: 100, labelOffset: Offset(0, -20));
  builder.edge(nodeInstagram, nodeUser, id: edgeConfirmLogin, label: '3) confirm login', curveBend: 200, labelOffset: Offset(0, 20));
  final edgeLoginConfirmed = builder.edge(nodeUser, nodeInstagram, label: '4) login confirmed', curveBend: 300, labelOffset: Offset(0, 20));
  builder.edge(nodeInstagram, nodeUser, id: edgeConfirmPermissions, label: '5) check permissions', curveBend: 450, labelOffset: Offset(0, -20));
  final edgePermissionsConfirmed = builder.edge(nodeUser, nodeInstagram, label: '6) permissions confirmed', curveBend: 700, labelOffset: Offset(0, -20));
  final edgeOk = builder.edge(nodeInstagram, nodeSomeSite, label: '7) ok', curveBend: -150, labelOffset: Offset(0, 20));

  // Nodes
  builder
    ..node<String, String>(nodeUser, position: const Offset(0.1, 0.3), title: "User",
      interceptors: [
        // Login overlay: fires when instagram asks user to confirm login
        ProcessInterceptor(
          onEdgeId: edgeConfirmLogin,
          execute: (packet, ctx) async {
            final username = "oauthuser@home.arpa";
            await ctx.showOverlay<String>(
              LoginWidget(
                onConfirm: () {},
                onCancel: () async {},
                siteName: "somesite",
                loginUser: LoginUser(username: username, password: "lmaolol"),
                textEntryDuration: ctx.processingDuration,
              ),
            );
            ctx.showFloatingText(Text(username));
            return InterceptResult.continueWith(packet);
          },
        ),
        // Permissions overlay: fires when instagram asks user to confirm permissions
        ProcessInterceptor(
          onEdgeId: edgeConfirmPermissions,
          execute: (packet, ctx) async {
            final client = OAuthClient(clientId: "1234", name: "somesite.com", redirectUri: "somesite.com/cb/rdr", scopes: ["scope1", "offline_access", "read_all_stuff"]);
            await ctx.showOverlay<String>(
              AuthorizeOAuthClientWidget(
                onConfirm: () {},
                onCancel: () async {},
                oauthClient: client,
              ),
            );
            ctx.showFloatingText(Text("granted: ${client.name}"));
            return InterceptResult.continueWith(packet);
          },
        ),
      ],
      processor: (d, router) async {
        await Future.delayed(router.processingDuration);

        if (d.fromEdgeId == edgeStart) {
          // Initial trigger → go to somesite
          return RouteDecision(toNodeId: nodeSomeSite, edgeId: edgeStart, label: "start", data: d.actualData ?? "");
        } else if (d.toEdgeId == edgeConfirmLogin) {
          // After login overlay → confirm to instagram
          return RouteDecision(toNodeId: nodeInstagram, edgeId: edgeLoginConfirmed, label: "login confirmed", data: edgeLoginConfirmed);
        } else if (d.toEdgeId == edgeConfirmPermissions) {
          // After permissions overlay → confirm to instagram
          return RouteDecision(toNodeId: nodeInstagram, edgeId: edgePermissionsConfirmed, label: "permissions confirmed", data: edgePermissionsConfirmed, disableNodeAfter: true);
        }

        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )
    ..node<String, String>(nodeSomeSite, position: const Offset(0.5, 0.2), title: "SomeSite.com", textStyle: TextStyle(fontSize: 10),
      processor: (d, router) async {
        await Future.delayed(router.processingDuration);

        if (d.toEdgeId == edgeStart) {
          // Got initial request → redirect to instagram
          return RouteDecision(toNodeId: nodeInstagram, edgeId: edgeRedirect, label: "redirecting", data: edgeRedirect);
        } else if (d.toEdgeId == edgeOk) {
          // Flow complete
          onEnd();
          return RouteDecision.terminal(resultingNodeState: NodeState.unselected);
        }

        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )
    ..node<String, String>(nodeInstagram, position: const Offset(0.8, 0.3), title: "instagram", textStyle: TextStyle(fontSize: 10),
      processor: (d, router) async {
        await Future.delayed(router.processingDuration);

        if (d.toEdgeId == edgeRedirect) {
          // Redirected → ask user to login
          return RouteDecision(toNodeId: nodeUser, edgeId: edgeConfirmLogin, label: "login", data: edgeConfirmLogin);
        } else if (d.toEdgeId == edgeLoginConfirmed) {
          // Login confirmed → ask user for permissions
          return RouteDecision(toNodeId: nodeUser, edgeId: edgeConfirmPermissions, label: "authorize", data: edgeConfirmPermissions);
        } else if (d.toEdgeId == edgePermissionsConfirmed) {
          // Permissions confirmed → tell somesite OK
          return RouteDecision(toNodeId: nodeSomeSite, edgeId: edgeOk, label: "permissions confirmed", data: edgeOk, disableNodeAfter: true);
        }

        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    );

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
