import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/painters/paper.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/graphnoderegion.dart' show floatTextStyle;
import 'package:oauthclient/widgets/nodes/node_process_config.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class GraphNodeWidget extends StatefulWidget {
  final GraphNodeData node;
  final VoidCallback? onTap;
  final GraphFlowController controller;
  final NodeProcessConfig? processConfig;
  final void Function(Widget) addFloatingText;
  final bool usePaper;
  final PaperSettings? paperSettings;

  const GraphNodeWidget({
    super.key,
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

  late NodeState _currentNodeState;
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

    _currentNodeState = widget.node.nodeState;
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
        _currentNodeState = widget.node.nodeState;
      });
    }
  }

  /// Trigger node processing
  Future<void> _triggerProcess(Object input) async {
    final config = widget.processConfig;
    if (config?.process == null) return;
    widget.addFloatingText(Text("${++_numProcessing}", style: floatTextStyle));

    setState(() {
      _currentNodeState = NodeState.inProgress;
      _processFuture = config!.process!(input)
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
          _currentNodeState = _lastResult!.state;
        }
      });

      // Auto-reset if configured
      if (config?.autoReset ?? false) {
        _resetTimer = Timer(config!.resetDelay, () {
          setState(() {
            if (_numProcessing <= 0) {
              _currentNodeState = NodeState.unselected;
            }
            _lastResult = null;
          });
        });
      }
    } on Exception catch (e) {
      widget.addFloatingText(Text("$e", style: floatTextStyle.copyWith(color: Colors.red)));
      setState(() {
        _currentNodeState = NodeState.error;
        _lastResult = ProcessResult(
          state: NodeState.error,
          message: "$e",
        );
      });
    } finally {
      _numProcessing--;
      if (_numProcessing <= 0) {
        setState(() {
          _currentNodeState = _lastResult?.state ?? NodeState.unselected;
        });
      }
    }
  }

  /// Handle data flow events
  void _onDataFlowEvent(GraphEvent event) {
    if (event is DataEnteredEvent && event.intoNodeId == widget.node.id) {
      _triggerProcess(event.data);
    } else if (event is DataExitedEvent) {
      // _handleDataEntered(event);
      // _squishController.forward().then((_) => _squishController.reverse());
    } else if (event is StopEvent && event.forAll || event.forNodeId == widget.node.id) {}
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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
              color: Theme.of(context).canvasColor,
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
                color: _blockState2color(_currentNodeState),
                progress: drawingProgress,
                gradient: _currentNodeState == NodeState.inProgress
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
          color: _blockState2color(_currentNodeState),
          gradient: _currentNodeState == NodeState.inProgress
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
      onTapDown: (_) => _onMouseDown(),
      onTapUp: (_) => _onMouseUp(),
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
