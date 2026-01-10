import 'package:oauthclient/src/graph_components/graph.dart';

class ProcessResult<T extends Object?> {
  final NodeState state;
  final String? message;
  final T? data;

  ProcessResult({
    required this.state,
    this.message,
    this.data,
  });
}

/// Callback signature for processing data in a node
typedef NodeProcess<Tin extends Object?, Tout extends Object?> = Future<ProcessResult<Tout>> Function(Tin);

/// Configuration for node processing behavior
class NodeProcessConfig<Tin extends Object?, Tout extends Object?> {
  final NodeProcess<Tin, Tout>? process;
  final Duration timeout;
  final bool autoReset;
  final Duration resetDelay;

  const NodeProcessConfig({
    this.process,
    this.timeout = const Duration(seconds: 5),
    this.autoReset = true,
    this.resetDelay = const Duration(seconds: 3),
  });
}
