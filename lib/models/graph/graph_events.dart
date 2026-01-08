import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

sealed class GraphEvent {
  final String? intoNodeId;
  final String? fromNodeId;

  const GraphEvent({this.intoNodeId, this.fromNodeId});
}

final class DataEnteredEvent<T extends Object?> extends GraphEvent {
  final DataPacket<T> data;
  const DataEnteredEvent({required String comingFromNodeId, required String intoNodeId, required this.data}) : super(fromNodeId: comingFromNodeId, intoNodeId: intoNodeId);
}

final class DataExitedEvent<T extends Object?> extends GraphEvent {
  final DataPacket<T> data;
  const DataExitedEvent({required String cameFromNodeId, required String goingToNodeId, required this.data}) : super(fromNodeId: cameFromNodeId, intoNodeId: goingToNodeId);
}

final class NodeEtherEvent extends GraphEvent {
  const NodeEtherEvent({required String cameFromNodeId}) : super(fromNodeId: cameFromNodeId);
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
    final nodeListeners = _listeners.entries.where((y) => y.key == event.fromNodeId || y.key == event.intoNodeId).map((y) => y.value).flattened;
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
