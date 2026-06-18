import 'dart:io';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:oauthclient/flatbuffers/acr_generated.dart';

class EventServer {
  final int port;
  HttpServer? _server;

  EventServer({this.port = 4242});

  bool get isRunning => _server != null;

  Future<void> start() async {
    final router = Router()
      ..post('/api/v1/events', _handleEvent)
      ..get('/api/v1/health', _handleHealth);

    final handler = const Pipeline()
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
    print('[EventServer] Listening on http://localhost:$port');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('[EventServer] Stopped');
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

      return Response(400,
        body: errorBytes,
        headers: {'content-type': 'flatbuffers/gravio/v1'},
      );
    }
  }

  Response _handleHealth(Request request) {
    return Response.ok('ok');
  }
}
