import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oauthclient/models/animated_label.dart';
import 'package:oauthclient/models/graph/connection.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:collection/collection.dart';

class GraphFlowController extends ChangeNotifier {
  final TickerProvider tickerProvider;

  // State
  final Map<String, bool> _activeNodes = {};
  final Map<String, bool> _glowingNodes = {};
  final List<(AnimatedLabel, AnimationController)> _animatingLabels = [];

  // Animation controllers
  late AnimationController _glowController;
  late AnimationController _squishController;
  // late AnimationController _labelFlowController;
  final List<AnimationController> _labelControllerPool = [];

  // Pre-allocate a reasonable pool size
  static const int _poolSize = 10;

  // Current node being squished
  String? _squishingNodeId;

  late GraphEventBus dataFlowEventBus;

  GraphFlowController({required this.tickerProvider}) : dataFlowEventBus = GraphEventBus() {
    _initializeControllers();
  }

  void _initializePool(int size) {
    for (int i = 0; i < size; i++) {
      _labelControllerPool.add(
        AnimationController(
          duration: const Duration(seconds: 2),
          vsync: tickerProvider,
        ),
      );
    }
  }

  void _initializeControllers() {
    _glowController = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: 1500),
    );

    _squishController = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: 200),
    );

    _initializePool(_poolSize);
  }

  AnimationController _getAvailableController() {
    // Find an idle controller
    for (var ctrl in _labelControllerPool) {
      if (!ctrl.isAnimating) {
        ctrl.reset();
        return ctrl;
      }
    }
    // Option 2: Reuse oldest animating label's controller (forcefully restart it)
    if (_animatingLabels.isNotEmpty) {
      final oldestLabel = _animatingLabels.first;
      var controllerUsed = removeAnimatingLabel(oldestLabel.$1.id) ?? _getAvailableController();
      return controllerUsed;
    }

    // Fallback: shouldn't reach here
    throw Exception('No available controllers and pool is full');
  }

  AnimationController? getControllerForLabel(String labelId) {
    return _animatingLabels.firstWhereOrNull((y) => y.$1.id == labelId)?.$2;
  }

  // Getters
  bool isNodeActive(String nodeId) => _activeNodes[nodeId] ?? false;
  bool isNodeGlowing(String nodeId) => _glowingNodes[nodeId] ?? false;
  String? get squishingNodeId => _squishingNodeId;
  Animation<double> get glowAnimation => _glowController;
  Animation<double> get squishAnimation => _squishController;
  List<(AnimatedLabel, AnimationController)> get animatingLabels => List.unmodifiable(_animatingLabels);

  // Methods
  Future<void> activateNode(String nodeId) async {
    _activeNodes[nodeId] = true;
    _glowingNodes[nodeId] = true;

    _squishingNodeId = nodeId;
    notifyListeners();

    await _squishController.forward(from: 0.0);

    // Keep glow going
    _glowController.repeat(reverse: true);
    notifyListeners();
  }

  void flowLabel(AnimatedLabel label, Duration duration) {
    var controller = addAnimatingLabel(label);
    controller.duration = duration;
    controller.forward(from: 0.0).then((_) {
      label.onComplete?.call();

      final fromId = label.connectionId.from();
      final toId = label.connectionId.to();

      // Emit DataEnteredEvent to trigger processing on arrival node
      dataFlowEventBus.emit(
        DataEnteredEvent<String>(
          comingFromNodeId: fromId,
          intoNodeId: toId,
          data: DataPacket(labelText: label.text, actualData: "p"),
        ),
      );

      removeAnimatingLabel(label.id);
    });
    notifyListeners();
  }

  AnimationController addAnimatingLabel(AnimatedLabel label) {
    var controller = _getAvailableController();
    _animatingLabels.add((label, controller));
    return controller;
  }

  AnimationController? removeAnimatingLabel(String labelid, {bool notify = true}) {
    final index = _animatingLabels.indexWhere((l) => l.$1.id == labelid);
    if (index != -1) {
      final (label, controller) = _animatingLabels.removeAt(index);
      // FIX: Stop the controller immediately if it's still running
      // This prevents the .then() callback from firing after removal
      if (controller.isAnimating) {
        controller.stop();
      }

      if (notify) {
        notifyListeners();
      }
      return controller;
    }
    return null;
  }

  void resetAll() {
    _activeNodes.clear();
    _glowingNodes.clear();
    _squishingNodeId = null;
    _glowController.reset();
    _squishController.reset();
    for (var y in _animatingLabels) {
      y.$2.reset();
    }
    _animatingLabels.clear();
    dataFlowEventBus.emit(const StopEvent());
    notifyListeners();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _squishController.dispose();
    dataFlowEventBus.dispose();
    for (final controller in _labelControllerPool) {
      controller.dispose();
    }
    super.dispose();
  }
}
