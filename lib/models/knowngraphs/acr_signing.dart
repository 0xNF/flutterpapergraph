import 'package:flutter/material.dart';
import 'package:oauthclient/models/graph/graph_builder.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

ControlFlowGraph acrSigningGraph(GraphRouter router, FnNodeStateCallback onUpdateNodeState, FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  // -- Node IDs --
  const nodeAuthor = 'author';
  const nodeAuthority = 'authority';
  const nodeHasher = 'hasher';
  const nodeManifest = 'manifest';
  const nodeSigner = 'signer';
  const nodeACR = 'acr';
  const nodeWorker = 'worker';

  final builder = GraphBuilder()
    ..startAt(nodeAuthor)
    ..properties(isAutomatic: true, hasEnd: true, hasTuneableTravelTime: true, hasTuneableProcessingTime: true);

  // -- Edges --
  // Signing pipeline
  final edgeSubmit = builder.edge(nodeAuthor, nodeAuthority, label: 'submit component', curveBend: -80, labelOffset: Offset(0, -25));
  final edgeHashFiles = builder.edge(nodeAuthority, nodeHasher, label: 'hash files', curveBend: -80, labelOffset: Offset(0, -25));
  final edgeFileHashes = builder.edge(nodeHasher, nodeManifest, label: 'SHA-256 hashes', curveBend: -80, labelOffset: Offset(0, -25));
  final edgeCanonicalJson = builder.edge(nodeManifest, nodeSigner, label: 'canonical JSON', curveBend: -80, labelOffset: Offset(0, -25));
  final edgeSigToAuthority = builder.edge(nodeSigner, nodeAuthority, label: 'component.sig.json', curveBend: -200, labelOffset: Offset(0, 20));

  // Deployment & verification
  final edgeDeploy = builder.edge(nodeAuthority, nodeACR, label: 'signed component', curveBend: -80, labelOffset: Offset(0, -25));
  final edgeVerifyWorker = builder.edge(nodeACR, nodeWorker, label: 'load + verify entry', curveBend: -80, labelOffset: Offset(0, -25));
  final edgeReVerified = builder.edge(nodeWorker, nodeACR, label: 're-verified ✓', curveBend: -200, labelOffset: Offset(0, 20));

  // -- Trust level labels for floating text --
  const trustLevels = [
    "Trust 1: signed, publisher unverified",
    "Trust 2: publisher verified",
    "Trust 3: verified + auto review",
    "Trust 4: verified + manual review",
  ];

  // -- Nodes --
  builder
    // Component Author — submits the component for signing
    ..node<String, String>(nodeAuthor, position: const Offset(0.03, 0.35), title: "Component\nAuthor", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.fromEdgeId == edgeSubmit) {
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("component/"), forNodeId: nodeAuthor));
          return RouteDecision(toNodeId: nodeAuthority, edgeId: edgeSubmit, label: "submit", data: "component_files");
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Project Authority — vets the component, assigns trust level, orchestrates signing
    ..node<String, String>(nodeAuthority, position: const Offset(0.20, 0.35), title: "Project\nAuthority", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);

        if (d.toEdgeId == edgeSubmit) {
          // Received component from author — start hashing
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("vetting..."), forNodeId: nodeAuthority));
          return RouteDecision(toNodeId: nodeHasher, edgeId: edgeHashFiles, label: "hash files", data: "component_files");
        } else if (d.toEdgeId == edgeSigToAuthority) {
          // Got signature back — pick a trust level and deploy
          final trust = trustLevels[2]; // Trust 3 for demo
          r.eventBus.emit(NodeFloatingTextEvent(text: Text(trust), forNodeId: nodeAuthority));
          return RouteDecision(toNodeId: nodeACR, edgeId: edgeDeploy, label: "deploy", data: "signed_component", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // SHA-256 Hasher — hashes every file in the component directory
    ..node<String, String>(nodeHasher, position: const Offset(0.40, 0.15), title: "SHA-256\nHasher", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.toEdgeId == edgeHashFiles) {
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("hashing files..."), forNodeId: nodeHasher));
          return RouteDecision(toNodeId: nodeManifest, edgeId: edgeFileHashes, label: "hashes", data: "file_hashes", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Manifest Builder — collects hashes into canonical JSON
    ..node<String, String>(nodeManifest, position: const Offset(0.55, 0.35), title: "Manifest\nBuilder", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.toEdgeId == edgeFileHashes) {
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("canonical JSON"), forNodeId: nodeManifest));
          return RouteDecision(toNodeId: nodeSigner, edgeId: edgeCanonicalJson, label: "manifest", data: "manifest_json", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Ed25519 Signer — signs the manifest with the authority's private key
    ..node<String, String>(nodeSigner, position: const Offset(0.40, 0.60), title: "Ed25519\nSigner", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.toEdgeId == edgeCanonicalJson) {
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("Ed25519 sign()"), forNodeId: nodeSigner));
          return RouteDecision(toNodeId: nodeAuthority, edgeId: edgeSigToAuthority, label: "signature", data: "component.sig.json", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // ACR Server — first signature verification on component load
    ..node<String, String>(nodeACR, position: const Offset(0.75, 0.35), title: "ACR\nServer", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);

        if (d.toEdgeId == edgeDeploy) {
          // First verification: check signature on load
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("verify #1 ✓"), forNodeId: nodeACR));
          return RouteDecision(toNodeId: nodeWorker, edgeId: edgeVerifyWorker, label: "init worker", data: "verified_component");
        } else if (d.toEdgeId == edgeReVerified) {
          // Worker confirmed re-verification — done
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("component loaded"), forNodeId: nodeACR));
          onEnd();
          return RouteDecision.terminal(resultingNodeState: NodeState.unselected);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    )

    // Worker — second signature verification on worker init
    ..node<String, String>(nodeWorker, position: const Offset(0.93, 0.35), title: "Worker", textStyle: TextStyle(fontSize: 9),
      processor: (d, r) async {
        await Future.delayed(r.processingDuration);
        if (d.toEdgeId == edgeVerifyWorker) {
          r.eventBus.emit(NodeFloatingTextEvent(text: Text("verify #2 ✓"), forNodeId: nodeWorker));
          return RouteDecision(toNodeId: nodeACR, edgeId: edgeReVerified, label: "re-verified", data: "ok", disableNodeAfter: true);
        }
        return RouteDecision.terminal(resultingNodeState: NodeState.selected);
      },
    );

  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
