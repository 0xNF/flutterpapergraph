import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

sealed class GraphEvent {
  final String? intoNodeId;
  final String? fromNodeId;
  final String? forNodeId;
  bool get forAll => intoNodeId == null && fromNodeId == null && forNodeId == null;
  final bool disableNodeAfter;
  final bool disableEdgeAfter;

  const GraphEvent({this.intoNodeId, this.fromNodeId, this.forNodeId, this.disableNodeAfter = false, this.disableEdgeAfter = false});
}

final class DataEnteredEvent<T extends Object?> extends GraphEvent {
  final DataPacket<T> data;

  const DataEnteredEvent({
    required String comingFromNodeId,
    required String intoNodeId,
    required this.data,
  }) : super(fromNodeId: comingFromNodeId, intoNodeId: intoNodeId);
}

final class DataExitedEvent<T extends Object?> extends GraphEvent {
  final DataPacket<T> data;
  final Duration? duration;
  final String? edgeId;

  const DataExitedEvent({required String cameFromNodeId, required String goingToNodeId, this.edgeId, required this.data, this.duration, super.disableEdgeAfter, super.disableNodeAfter, super.forNodeId})
    : super(fromNodeId: cameFromNodeId, intoNodeId: goingToNodeId);
}

final class NodeEtherEvent extends GraphEvent {
  const NodeEtherEvent({required String cameFromNodeId}) : super(fromNodeId: cameFromNodeId);
}

final class StopEvent extends GraphEvent {
  const StopEvent({super.forNodeId});

  bool get forAll => super.forNodeId == null;
}

final class NodeStateChangedEvent extends GraphEvent {
  final NodeState? oldState;
  final NodeState newState;

  const NodeStateChangedEvent({
    this.oldState,
    required this.newState,
    required super.forNodeId,
    super.disableEdgeAfter,
    super.disableNodeAfter,
  });
}

final class EdgeStateChangedEvent extends GraphEvent {
  final EdgeState? oldState;
  final EdgeState newState;
  final String edgeId;

  const EdgeStateChangedEvent({
    this.oldState,
    required this.newState,
    required this.edgeId,
  });
}

class DataPacket<T extends Object?> {
  final String labelText;
  final T? actualData;

  const DataPacket({required this.labelText, required this.actualData});
}

typedef FnUnsub = VoidCallback;

/// EventBus for data flow events
/// Manages subscriptions and broadcasts data flow events to nodes
class GraphEventBus extends ChangeNotifier {
  final Map<String, List<Function(GraphEvent)>> _listeners = {};
  final List<Function(GraphEvent)> _unconditionalListeners = [];

  /// Subscribe to events for a specific node
  FnUnsub subscribe(String nodeId, Function(GraphEvent) callback) {
    _listeners.putIfAbsent(nodeId, () => []).add(callback);
    return () => _unsubscribe(nodeId, callback);
  }

  FnUnsub subscribeUnconditional(Function(GraphEvent) callback) {
    _unconditionalListeners.add(callback);
    return () => _unsubscribeUnconditional(callback);
  }

  /// Unsubscribe from events
  void _unsubscribe(String nodeId, Function(GraphEvent) callback) {
    _listeners[nodeId]?.remove(callback);
    if (_listeners[nodeId]?.isEmpty ?? false) {
      _listeners.remove(nodeId);
    }
  }

  void _unsubscribeUnconditional(Function(GraphEvent) callback) {
    _unconditionalListeners.remove(callback);
  }

  /// Broadcast a data flow event
  void emit(GraphEvent event) {
    final nodeListeners = event.forAll ? _listeners.entries.map((y) => y.value).flattened : _listeners.entries.where((y) => y.key == event.fromNodeId || y.key == event.intoNodeId).map((y) => y.value).flattened;
    for (final callback in nodeListeners) {
      callback(event);
    }
    for (final unconditional in _unconditionalListeners) {
      unconditional(event);
    }
    notifyListeners(); // For debugging/UI updates
  }

  /// Get all listeners for a node (for debugging)
  int getListenerCount(String nodeId) => _listeners[nodeId]?.length ?? 0;

  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
}
