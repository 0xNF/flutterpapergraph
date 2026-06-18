import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

ControlFlowGraph authGraph2AccessToken(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  const nodeApplication = 'start';
  const nodeAuthServer = 'instagramAuthServer';
  const nodeAPIServer = 'instagramAPIServer';

  final builder = GraphBuilder()
    ..startAt(nodeApplication)
    ..properties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true);

  // Edges
  final edgeStart = builder.edge(nodeApplication, nodeAuthServer, label: 'Auth Request\n{ClientId, Scope, GrantType}', curveBend: -100, labelOffset: Offset(0, -25));
  final edgeReturnAccessToken = builder.edge(nodeAuthServer, nodeApplication, label: 'Access Token', curveBend: 200, labelOffset: Offset(0, -20));
  final edgePassAccessToken = builder.edge(nodeApplication, nodeAPIServer, label: 'API Call', curveBend: 600, labelOffset: Offset(0, -30));
  final edgeReturnAPIResult = builder.edge(nodeAPIServer, nodeApplication, label: 'API Result', curveBend: 200, labelOffset: Offset(0, -20));

  // Nodes
  builder
    ..node<String, String>(nodeApplication, position: const Offset(0.1, 0.2), title: "Application",
      processor: (d, router) async {
        await Future.delayed(router.processingDuration);

        if (d.fromEdgeId == edgeStart) {
          // Initial trigger → send to auth server
          return RouteDecision(toNodeId: nodeAuthServer, edgeId: edgeStart, label: "start", data: d.actualData ?? "");
        } else if (d.toEdgeId == edgeReturnAccessToken || d.toEdgeId == edgeReturnAPIResult) {
          // Got token or API result → send to API server
          final label = d.toEdgeId == edgeReturnAPIResult ? "API request" : "bearer: xyz";
          return RouteDecision(
            toNodeId: nodeAPIServer,
            edgeId: edgePassAccessToken,
            label: label,
            data: d.toEdgeId == edgeReturnAPIResult ? 'API request' : "access token received",
            disableEdgeAfter: false,
            disableNodeAfter: false,
          );
        }

        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )
    ..node<String, String>(nodeAuthServer, position: const Offset(0.8, 0.2), title: "Auth Server", textStyle: TextStyle(fontSize: 10),
      processor: (d, router) async {
        await Future.delayed(router.processingDuration);

        if (d.toEdgeId == edgeStart) {
          return RouteDecision(
            toNodeId: nodeApplication,
            edgeId: edgeReturnAccessToken,
            label: "access_token",
            data: "Authorization successful",
          );
        }

        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )
    ..node<String, String>(nodeAPIServer, position: const Offset(0.8, 0.8), title: "API Server", textStyle: TextStyle(fontSize: 10),
      processor: (d, router) async {
        await Future.delayed(router.processingDuration);

        if (d.toEdgeId == edgePassAccessToken) {
          return RouteDecision(
            toNodeId: nodeApplication,
            edgeId: edgeReturnAPIResult,
            label: "data",
            data: "access token is valid",
            disableEdgeAfter: false,
            disableNodeAfter: false,
          );
        }

        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    );

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
