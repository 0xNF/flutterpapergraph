import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/knowngraphs/auth_2_access.dart';
import 'package:oauthclient/models/knowngraphs/racers.dart';
import 'package:oauthclient/models/knowngraphs/simple_auth_graph.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

enum KnownGraph {
  racers("Racers"),
  simpleAuth1("Oauth Flow (user perspective)"),
  authGraph2("OAuth Flow (access token acquisition)"),
  ;

  final String graphTitle;

  const KnownGraph(this.graphTitle);
}

typedef FnContextFetcher = BuildContext Function();
typedef FnNodeStateCallback = void Function(String, NodeState, NodeState, bool);

typedef FnGraphLoad = ControlFlowGraph Function(GraphFlowController flowController, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd);

FnGraphLoad loadGraph(KnownGraph whichGraph) {
  return switch (whichGraph) {
    KnownGraph.racers => racers,
    KnownGraph.simpleAuth1 => simpleAuthGraph1,
    KnownGraph.authGraph2 => authGraph2AccessToken,
  };
}
