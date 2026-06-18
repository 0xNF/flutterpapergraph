import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' hide Router;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:oauthclient/controllers/graph_mutation_controller.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/flatbuffers/acr_generated.dart';

class EventServer {
  final int port;
  HttpServer? _server;

  /// Set by the UI layer when a graph is initialized.
  /// HTTP graph-mutation endpoints delegate to this controller.
  GraphMutationController? mutationController;

  EventServer({this.port = 4242});

  bool get isRunning => _server != null;

  Future<void> start() async {
    final router = Router()
      ..post('/api/v1/events', _handleEvent)
      ..get('/api/v1/health', _handleHealth)
      ..post('/api/v1/graph/nodes', _handleAddNode)
      ..delete('/api/v1/graph/nodes/<nodeId>', _handleRemoveNode)
      ..post('/api/v1/graph/edges', _handleAddEdge)
      ..delete('/api/v1/graph/edges/<edgeId>', _handleRemoveEdge)
      ..post('/api/v1/graph/traverse', _handleTraverse)
      ..get('/api/v1/graph', _handleGetGraph);

    final handler = const Pipeline().addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
    print('[EventServer] Listening on http://localhost:$port');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('[EventServer] Stopped');
  }

  Response _jsonOk(Object body) => Response.ok(
    jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );

  Response _jsonError(int status, String message) => Response(
    status,
    body: jsonEncode({'error': message}),
    headers: {'content-type': 'application/json'},
  );

  /// POST /api/v1/graph/nodes
  /// Body: { "id"?: string, "title": string, "x"?: double, "y"?: double,
  ///         "state"?: "unselected"|"selected"|"inProgress"|"error"|"disabled" }
  ///
  /// Upsert: if a node with the given id already exists, updates its position
  /// and state. Otherwise creates a new node with forward routing.
  Future<Response> _handleAddNode(Request request) async {
    final mc = mutationController;
    if (mc == null) return _jsonError(409, 'No active graph');

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return _jsonError(400, 'Invalid JSON: $e');
    }

    final title = body['title'] as String?;
    if (title == null) return _jsonError(400, 'Missing required field: title');

    final state = _parseNodeState(body['state'] as String?);

    Offset? position;
    if (body['x'] != null && body['y'] != null) {
      position = Offset(
        (body['x'] as num).toDouble(),
        (body['y'] as num).toDouble(),
      );
    }

    final requestedId = body['id'] as String?;
    final existed = requestedId != null && mc.graph.getNode(requestedId) != null;

    final nodeId = mc.upsertDynamicNode(
      id: requestedId,
      title: title,
      position: position,
      state: state,
    );

    return _jsonOk({'id': nodeId, 'updated': existed});
  }

  /// DELETE /api/v1/graph/nodes/\<nodeId>
  Response _handleRemoveNode(Request request, String nodeId) {
    final mc = mutationController;
    if (mc == null) return _jsonError(409, 'No active graph');

    final node = mc.graph.getNode(nodeId);
    if (node == null) return _jsonError(404, 'Node not found: $nodeId');

    mc.removeNode(nodeId);
    return _jsonOk({'removed': nodeId});
  }

  /// POST /api/v1/graph/edges
  /// Body: { "id"?: string, "fromNodeId": string, "toNodeId": string,
  ///         "label"?: string, "curveBend"?: double }
  Future<Response> _handleAddEdge(Request request) async {
    final mc = mutationController;
    if (mc == null) return _jsonError(409, 'No active graph');

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return _jsonError(400, 'Invalid JSON: $e');
    }

    final fromNodeId = body['fromNodeId'] as String?;
    final toNodeId = body['toNodeId'] as String?;
    if (fromNodeId == null || toNodeId == null) {
      return _jsonError(400, 'Missing required fields: fromNodeId, toNodeId');
    }

    if (mc.graph.getNode(fromNodeId) == null) {
      return _jsonError(404, 'Source node not found: $fromNodeId');
    }
    if (mc.graph.getNode(toNodeId) == null) {
      return _jsonError(404, 'Target node not found: $toNodeId');
    }

    final edgeId = mc.addDynamicEdge(
      id: body['id'] as String?,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      label: body['label'] as String?,
      curveBend: (body['curveBend'] as num?)?.toDouble() ?? 0,
    );

    return _jsonOk({'id': edgeId});
  }

  /// DELETE /api/v1/graph/edges/<edgeId>
  Response _handleRemoveEdge(Request request, String edgeId) {
    final mc = mutationController;
    if (mc == null) return _jsonError(409, 'No active graph');

    final exists = mc.graph.edges.any((e) => e.id == edgeId);
    if (!exists) return _jsonError(404, 'Edge not found: $edgeId');

    mc.removeEdge(edgeId);
    return _jsonOk({'removed': edgeId});
  }

  /// GET /api/v1/graph
  /// Returns current graph state: nodes, edges, properties.
  Response _handleGetGraph(Request request) {
    final mc = mutationController;
    if (mc == null) return _jsonError(409, 'No active graph');

    final nodes = mc.graph.nodes
        .map(
          (n) => {
            'id': n.id,
            'title': n.contents.stepTitle,
            'x': n.logicalPosition.dx,
            'y': n.logicalPosition.dy,
            'state': n.nodeState.name,
          },
        )
        .toList();

    final edges = mc.graph.edges
        .map(
          (e) => {
            'id': e.id,
            'fromNodeId': e.fromNodeId,
            'toNodeId': e.toNodeId,
            'label': e.label,
            'curveBend': e.curveBend,
            'state': e.edgeState.name,
          },
        )
        .toList();

    return _jsonOk({
      'nodes': nodes,
      'edges': edges,
      'startingNodeId': mc.graph.startingNodeId,
    });
  }

  /// POST /api/v1/graph/traverse
  /// Body: { "fromNodeId": string, "toNodeId": string, "edgeId"?: string,
  ///         "label"?: string, "data"?: string }
  ///
  /// Sends a data packet from one node to another along an edge,
  /// triggering the full animation and processing pipeline.
  Future<Response> _handleTraverse(Request request) async {
    final mc = mutationController;
    if (mc == null) return _jsonError(409, 'No active graph');

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return _jsonError(400, 'Invalid JSON: $e');
    }

    final fromNodeId = body['fromNodeId'] as String?;
    final toNodeId = body['toNodeId'] as String?;
    if (fromNodeId == null || toNodeId == null) {
      return _jsonError(400, 'Missing required fields: fromNodeId, toNodeId');
    }

    if (mc.graph.getNode(fromNodeId) == null) {
      return _jsonError(404, 'Source node not found: $fromNodeId');
    }
    if (mc.graph.getNode(toNodeId) == null) {
      return _jsonError(404, 'Target node not found: $toNodeId');
    }

    final label = body['label'] as String? ?? '';
    final data = body['data'] as String?;
    final edgeId = body['edgeId'] as String?;

    mc.router.executeRoute(
      fromNodeId,
      RouteDecision(
        toNodeId: toNodeId,
        edgeId: edgeId,
        label: label,
        data: data,
        disableEdgeAfter: false,
      ),
    );

    return _jsonOk({'ok': true});
  }

  NodeState _parseNodeState(String? value) {
    if (value == null) return NodeState.unselected;
    return NodeState.values.firstWhere(
      (s) => s.name == value,
      orElse: () => NodeState.unselected,
    );
  }

  Future<Response> _handleEvent(Request request) async {
    final contentType = request.headers['content-type'] ?? '';
    if (!contentType.contains('flatbuffers')) {
      return Response(
        415,
        body: 'Expected content-type: flatbuffers/gravio/v1',
      );
    }

    final Uint8List bytes;
    try {
      final bodyBytes = await request.read().toList();
      bytes = Uint8List.fromList(bodyBytes.expand((b) => b).toList());
    } catch (e) {
      return Response(400, body: 'Failed to read request body: $e');
    }

    if (bytes.isEmpty) {
      return Response(400, body: 'Empty request body');
    }

    try {
      RunRequest(bytes); // validate the buffer parses

      // Build a ComponentResult acknowledging receipt
      final responseBytes = ComponentResultObjectBuilder(
        componentRunResult: ComponentRunResult.Finished,
      ).toBytes();

      return Response.ok(
        responseBytes,
        headers: {'content-type': 'flatbuffers/gravio/v1'},
      );
    } catch (e) {
      print('[EventServer] Failed to parse RunRequest: $e');

      final errorBytes = ComponentResultObjectBuilder(
        componentRunResult: ComponentRunResult.Error,
        postError: PostErrorObjectBuilder(
          code: 'parse_error',
          message: 'Failed to parse RunRequest: $e',
        ),
      ).toBytes();

      return Response(
        400,
        body: errorBytes,
        headers: {'content-type': 'flatbuffers/gravio/v1'},
      );
    }
  }

  Response _handleHealth(Request request) {
    return Response.ok('ok');
  }
}
