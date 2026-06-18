import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/auth_2_access.dart';
import 'package:oauthclient/models/knowngraphs/racers.dart';
import 'package:oauthclient/models/knowngraphs/acr.dart';
import 'package:oauthclient/models/knowngraphs/new_graph.dart';
import 'package:oauthclient/models/knowngraphs/simple_auth_graph.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

enum KnownGraph {
  racers("Racers", disableAfterProcessing: false),
  simpleAuth1("Oauth Flow (user perspective)"),
  authGraph2("OAuth Flow (access token acquisition)"),
  acr("ACR (Addon Component Runner)"),
  newGraph("New Graph"),
  ;

  final String graphTitle;
  final bool disableAfterProcessing;

  const KnownGraph(this.graphTitle, {this.disableAfterProcessing = true});
}

typedef FnContextFetcher = BuildContext Function();
typedef FnNodeStateCallback = void Function(String, NodeState, NodeState, bool);

typedef FnGraphLoad = ControlFlowGraph Function(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd);

FnGraphLoad loadGraph(KnownGraph whichGraph) {
  return switch (whichGraph) {
    KnownGraph.racers => racers,
    KnownGraph.simpleAuth1 => simpleAuthGraph1,
    KnownGraph.authGraph2 => authGraph2AccessToken,
    KnownGraph.acr => acrGraph,
    KnownGraph.newGraph => newGraph,
  };
}
