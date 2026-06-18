import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/graph/graph_router.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';

/// A side-effect hook that fires before a node's processor runs.
///
/// Interceptors separate side effects (UI overlays, floating text, timers)
/// from pure routing logic. They run in declaration order and can modify
/// the packet or short-circuit the processor entirely.
class ProcessInterceptor {
  /// If non-null, this interceptor only fires when data arrives via this edge ID.
  final String? onEdgeId;

  /// General predicate checked against the incoming DataPacket.
  /// Ignored if [onEdgeId] is set.
  final bool Function(DataPacket)? when;

  /// The side effect to execute. Returns an [InterceptResult] indicating
  /// whether to continue to the processor or short-circuit with a routing decision.
  final Future<InterceptResult> Function(DataPacket, InterceptContext) execute;

  const ProcessInterceptor({
    this.onEdgeId,
    this.when,
    required this.execute,
  });

  /// Whether this interceptor should fire for the given packet.
  bool shouldFire(DataPacket packet) {
    if (onEdgeId != null) {
      return packet.toEdgeId == onEdgeId || packet.fromEdgeId == onEdgeId;
    }
    return when?.call(packet) ?? true;
  }
}

/// Result of an interceptor execution.
sealed class InterceptResult {
  const InterceptResult();

  /// Continue to the processor with this (possibly modified) packet.
  const factory InterceptResult.continueWith(DataPacket packet) = ContinueResult;

  /// Skip the processor entirely and use this route decision.
  const factory InterceptResult.shortCircuit(RouteDecision decision) = ShortCircuitResult;
}

final class ContinueResult extends InterceptResult {
  final DataPacket packet;
  const ContinueResult(this.packet);
}

final class ShortCircuitResult extends InterceptResult {
  final RouteDecision decision;
  const ShortCircuitResult(this.decision);
}

/// Rich context given to interceptors for performing side effects.
///
/// Provides convenience methods for common patterns like showing overlays
/// and floating text, replacing the verbose manual Completer + event emission
/// boilerplate.
class InterceptContext {
  final GraphFlowController flowController;
  final FnContextFetcher getContext;
  final String nodeId;

  InterceptContext({
    required this.flowController,
    required this.getContext,
    required this.nodeId,
  });

  GraphEventBus get eventBus => flowController.dataFlowEventBus;

  /// Show floating text above this node.
  void showFloatingText(Text text) {
    eventBus.emit(NodeFloatingTextEvent(text: text, forNodeId: nodeId));
  }

  /// Show a widget overlay and await user interaction.
  /// Replaces the verbose Completer + ShowWidgetOverlayEvent pattern.
  Future<T> showOverlay<T>(Widget widget) {
    final completer = Completer<T>();
    eventBus.emit(ShowWidgetOverlayEvent(
      widget: widget,
      completer: completer,
      forNodeId: nodeId,
    ));
    return completer.future;
  }

  /// Get current processing duration from inherited settings.
  Duration get processingDuration => InheritedGraphConfigSettings.of(getContext()).stepSettings.processingDuration;

  /// Get current travel duration from inherited settings.
  Duration get travelDuration => InheritedGraphConfigSettings.of(getContext()).stepSettings.travelDuration;
}
