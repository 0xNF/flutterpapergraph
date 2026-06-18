import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';

String _uuid() {
  final rng = Random();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

ControlFlowGraph newGraph(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  final graphId = _uuid();
  const nodeStart = 'start';

  final builder = GraphBuilder()
    ..startAt(nodeStart)
    ..properties()
    ..node<String, String>(
      nodeStart,
      position: const Offset(0.5, 0.5),
      title: graphId,
      processor: (d, r) async => RouteDecision.terminal(),
    );

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
