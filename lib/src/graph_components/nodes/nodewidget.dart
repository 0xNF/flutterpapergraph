import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/painters/paper.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class GraphNodeWidget extends StatefulWidget {
  final GraphNodeData node;
  final NodeSettings nodeSettings;
  final VoidCallback? onTap;
  final GraphFlowController controller;
  final NodeProcessConfig? processConfig;
  final void Function(Widget) addFloatingText;
  final bool usePaper;
  final PaperSettings? paperSettings;

  const GraphNodeWidget({
    super.key,
    required this.nodeSettings,
    required this.node,
    required this.onTap,
    required this.controller,
    required this.addFloatingText,
    this.processConfig,
    this.usePaper = true,
    this.paperSettings,
  });

  @override
  State<GraphNodeWidget> createState() => _GraphNodeWidgetState();
}

class _GraphNodeWidgetState extends State<GraphNodeWidget> with TickerProviderStateMixin {
  late AnimationController _vaporwaveController;
  late AnimationController _squishController;
  late Animation<double> _squishAnimation;
  late AnimationController _drawingController;

  late final FnUnsub _fnUnsub;
  int _numProcessing = 0;

  Future<ProcessResult>? _processFuture;
  ProcessResult? _lastResult;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _vaporwaveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _squishController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _squishAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _squishController, curve: Curves.decelerate),
    );

    if (widget.usePaper) {
      // Drawing animation controller - only needed for paper style
      _drawingController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );
      _drawingController.repeat();
    }

    // Subscribe to data flow events for this node
    _fnUnsub = widget.controller.dataFlowEventBus.subscribe(widget.node.id, _onDataFlowEvent);
  }

  @override
  void dispose() {
    _vaporwaveController.dispose();
    _squishController.dispose();
    _drawingController.dispose();
    _resetTimer?.cancel();
    _fnUnsub();
    super.dispose();
  }

  @override
  void didUpdateWidget(GraphNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.nodeState != widget.node.nodeState) {
      setState(() {
        widget.node.setNodeState(widget.node.nodeState);
      });
    }
  }

  /// Trigger node processing
  Future<void> _triggerProcess(Object? input) async {
    final config = widget.processConfig;
    if (config?.process == null || widget.node.nodeState == NodeState.disabled) return;
    widget.addFloatingText(Text("${++_numProcessing}", style: widget.nodeSettings.floatingTextStyle));

    setState(() {
      widget.node.setNodeState(NodeState.inProgress);
      _processFuture = config!.process!(input)
          .then((result) => result) // Force type inference
          .whenComplete(() => _squishController.forward().then((_) => _squishController.reverse()))
          .timeout(
            config.timeout,
            onTimeout: () => ProcessResult(
              state: NodeState.error,
              message: "process timeout",
            ),
          );
    });

    try {
      _lastResult = await _processFuture;
      setState(() {
        if (_numProcessing <= 0) {
          widget.node.setNodeState(_lastResult!.state);
        }
      });

      // Auto-reset if configured
      if ((config?.autoReset ?? false) && (widget.node.nodeState != NodeState.disabled || _lastResult?.state == NodeState.disabled)) {
        _resetTimer = Timer(config!.resetDelay, () {
          setState(() {
            if (_numProcessing <= 0) {
              widget.node.setNodeState(_lastResult?.state ?? NodeState.unselected);
            }
          });
        });
      }
    } on Exception catch (e) {
      widget.addFloatingText(Text("$e", style: widget.nodeSettings.floatingTextStyle.copyWith(color: Colors.red)));
      setState(() {
        widget.node.setNodeState(NodeState.error);
        _lastResult = ProcessResult(
          state: NodeState.error,
          message: "$e",
        );
      });
    } finally {
      _numProcessing--;
      if (_numProcessing <= 0 && widget.node.nodeState != NodeState.disabled) {
        setState(() {
          widget.node.setNodeState(_lastResult?.state ?? NodeState.unselected);
        });
      }
    }
  }

  /// Handle data flow events
  void _onDataFlowEvent(GraphEvent event) {
    if (event is DataEnteredEvent && event.intoNodeId == widget.node.id) {
      _triggerProcess(event.data.actualData);
    } else if (event is DataExitedEvent) {
      // _handleDataEntered(event);
      // _squishController.forward().then((_) => _squishController.reverse());
    } else if (event is StopEvent && event.forAll || event.forNodeId == widget.node.id) {
      setState(() {
        _lastResult = null;
        _resetTimer?.cancel();
      });
    } else if (event is NodeStateChangedEvent && event.forNodeId == widget.node.id) {
      setState(() {
        if (widget.node.nodeState == NodeState.disabled) {
          _lastResult = ProcessResult(state: NodeState.disabled);
          // Cancel any pending reset timer since we're now explicitly disabled
          _resetTimer?.cancel();
        }
        if (event.newState == NodeState.unselected) {
          _lastResult = null;
        } else {
          widget.node.setNodeState(event.newState, notify: false);
          // Clear state when reset to unselected
          _lastResult = null;
          _resetTimer?.cancel();
        }
      });
    }
  }

  void _onMouseDown() {
    _squishController.forward();
  }

  void _reversal(AnimationStatus s) {
    if (s.isCompleted) {
      _squishController.reverse();
      _squishController.removeStatusListener(_reversal);
    }
  }

  void _onMouseUp() {
    if (!_squishController.isAnimating) {
      _squishController.reverse();
    } else {
      _squishController.addStatusListener(_reversal);
    }
    widget.onTap?.call();
  }

  static Color _blockState2color(NodeState blockState) {
    return switch (blockState) {
      NodeState.unselected => Colors.grey,
      NodeState.selected => Colors.green,
      NodeState.inProgress => Colors.greenAccent,
      NodeState.error => Colors.red,
      NodeState.disabled => Colors.grey[850]!,
    };
  }

  Widget _buildInnerContent(double squishValue) {
    return Transform.scale(
      scaleX: 1 / (1 + (squishValue * 0.1)),
      scaleY: 1 / (1 - (squishValue * 0.3)),
      child: Center(
        child: Text(
          widget.node.contents.stepTitle,
          textAlign: TextAlign.center,
          style: widget.node.contents.textStyle.copyWith(color: widget.node.nodeState == NodeState.disabled ? Colors.grey[800] : null),
        ),
      ),
    );
  }

  Widget _buildBorder(BuildContext context, double squishValue) {
    if (widget.usePaper) {
      // Paper style: hand-drawn border with overlay painters
      final drawingProgress = _drawingController.value;
      return Stack(
        children: [
          // Inner content container
          Container(
            margin: const EdgeInsets.all(5),
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: widget.node.nodeState == NodeState.disabled ? Colors.grey[900]! : Theme.of(context).canvasColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: _buildInnerContent(squishValue),
          ),
          // Hand-drawn border overlay
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
            ),
            child: CustomPaint(
              painter: HandDrawnRectanglePainter(
                color: _blockState2color(widget.node.nodeState),
                progress: widget.node.nodeState == NodeState.disabled ? 0 : drawingProgress,
                gradient: widget.node.nodeState == NodeState.inProgress
                    ? SweepGradient(
                        tileMode: TileMode.mirror,
                        center: Alignment.topLeft,
                        startAngle: _vaporwaveController.value * 2 * pi,
                        endAngle: _vaporwaveController.value * (2 * pi) + pi,
                        colors: const [
                          Color(0xFFFF10F0),
                          Color(0xFF00F0FF),
                        ],
                      )
                    : null,
              ),
            ),
          ),
        ],
      );
    } else {
      // Original style: solid colored border container with inner decorated container
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: _blockState2color(widget.node.nodeState),
          gradient: widget.node.nodeState == NodeState.inProgress
              ? SweepGradient(
                  tileMode: TileMode.mirror,
                  center: Alignment.topLeft,
                  startAngle: _vaporwaveController.value * 2 * pi,
                  endAngle: _vaporwaveController.value * (2 * pi) + pi,
                  colors: const [
                    Color(0xFFFF10F0),
                    Color(0xFF00F0FF),
                  ],
                )
              : null,
        ),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildInnerContent(squishValue),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.node.nodeState == NodeState.disabled ? null : (_) => _onMouseDown(),
      onTapUp: widget.node.nodeState == NodeState.disabled ? null : (_) => _onMouseUp(),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return AnimatedBuilder(
            animation: Listenable.merge([
              _vaporwaveController,
              _squishController,
              if (widget.usePaper) _drawingController,
            ]),
            builder: (context, _) {
              final squishValue = _squishAnimation.value;
              final squishX = 1 + (squishValue * 0.1);
              final squishY = 1 - (squishValue * 0.3);

              return Transform.scale(
                scaleX: squishX,
                scaleY: squishY,
                child: _buildBorder(context, squishValue),
              );
            },
          );
        },
      ),
    );
  }
}
