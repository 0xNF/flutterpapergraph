import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/graphnoderegion.dart' show floatTextStyle;
import 'package:oauthclient/widgets/nodes/node_process_config.dart';

class GraphNodeWidget extends StatefulWidget {
  final GraphNodeData node;
  final VoidCallback? onTap;
  final GraphFlowController controller;
  final NodeProcessConfig? processConfig;
  final void Function(Widget) addFloatingText;
  final bool usePaper;

  const GraphNodeWidget({
    super.key,
    required this.node,
    required this.onTap,
    required this.controller,
    required this.addFloatingText,
    this.processConfig,
    this.usePaper = true,
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

    // Drawing animation controller - only needed for paper style
    _drawingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (widget.usePaper) {
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
          // Wiggle lines animation overlay
          Positioned.fill(
            child: CustomPaint(
              painter: WigglePainter(
                progress: drawingProgress,
                color: _blockState2color(_currentNodeState),
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

/// Custom painter for hand-drawn rectangle effect with subtle noisy borders
class HandDrawnRectanglePainter extends CustomPainter {
  final Color color;
  final double progress;
  final Gradient? gradient;

  HandDrawnRectanglePainter({
    required this.color,
    required this.progress,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 2.5;
    final padding = 5.0;
    final innerSize = size.width - (padding * 2);
    const radius = 15.0;
    const segmentLength = 3.0;
    const noiseAmount = 0.4;

    final centerPath = Path();

    // Helper function to add noisy line segment
    void addNoisyLine(double x1, double y1, double x2, double y2, int seedOffset) {
      final random = Random((progress * 3).floor() + seedOffset);
      final dx = x2 - x1;
      final dy = y2 - y1;
      final distance = sqrt(dx * dx + dy * dy);
      final steps = (distance / segmentLength).ceil();

      centerPath.moveTo(x1, y1);

      for (int i = 1; i <= steps; i++) {
        final t = i / steps;
        final baseX = x1 + dx * t;
        final baseY = y1 + dy * t;

        // Add random noise perpendicular to the line
        final noisePerp = (random.nextDouble() - 0.5) * 2 * noiseAmount;
        final noiseTangent = (random.nextDouble() - 0.5) * 2 * noiseAmount * 0.5;

        // Perpendicular offset
        final perpX = -dy / distance * noisePerp;
        final perpY = dx / distance * noisePerp;

        // Tangential offset
        final tangentX = dx / distance * noiseTangent;
        final tangentY = dy / distance * noiseTangent;

        centerPath.lineTo(baseX + perpX + tangentX, baseY + perpY + tangentY);
      }
    }

    // Calculate the center line of the border (middle of the stroke)
    final borderOffset = padding + strokeWidth / 2;
    final borderSize = innerSize - strokeWidth;

    // Top side
    addNoisyLine(borderOffset + radius, borderOffset, borderOffset + borderSize - radius, borderOffset, 0);

    // Top-right corner - draw a proper rounded corner
    final topRightX = borderOffset + borderSize;
    final topRightY = borderOffset;
    centerPath.quadraticBezierTo(
      topRightX + radius * 0.25,
      topRightY,
      topRightX,
      topRightY + radius,
    );

    // Right side
    addNoisyLine(topRightX, borderOffset + radius, topRightX, borderOffset + borderSize - radius, 1);

    // Bottom-right corner
    final bottomRightX = borderOffset + borderSize;
    final bottomRightY = borderOffset + borderSize;
    centerPath.quadraticBezierTo(
      bottomRightX,
      bottomRightY - radius * 0.25,
      bottomRightX - radius,
      bottomRightY,
    );

    // Bottom side
    addNoisyLine(borderOffset + borderSize - radius, bottomRightY, borderOffset + radius, bottomRightY, 2);

    // Bottom-left corner
    final bottomLeftX = borderOffset;
    final bottomLeftY = borderOffset + borderSize;
    centerPath.quadraticBezierTo(
      bottomLeftX - radius * 0.25,
      bottomLeftY,
      bottomLeftX,
      bottomLeftY - radius,
    );

    // Left side
    addNoisyLine(bottomLeftX, borderOffset + borderSize - radius, bottomLeftX, borderOffset + radius, 3);

    // Top-left corner
    final topLeftX = borderOffset;
    final topLeftY = borderOffset;
    centerPath.quadraticBezierTo(
      topLeftX,
      topLeftY + radius * 0.25,
      topLeftX + radius,
      topLeftY,
    );

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (gradient != null) {
      paint.shader = gradient!.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    } else {
      paint.color = color;
    }

    canvas.drawPath(centerPath, paint);
  }

  @override
  bool shouldRepaint(HandDrawnRectanglePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.gradient != gradient;
  }
}

/// Wiggle lines painter for continuous drawing effect
class WigglePainter extends CustomPainter {
  final double progress;
  final Color color;

  WigglePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.2
      ..color = color.withOpacity(0.15)
      ..strokeCap = StrokeCap.round;

    // Draw animated dashes around the perimeter
    const dashCount = 12;
    for (int i = 0; i < dashCount; i++) {
      final angle = (i / dashCount) * 2 * pi;
      final offset = (progress + (i / dashCount)) % 1.0;

      final radius = 50.0;
      final centerX = size.width / 2;
      final centerY = size.height / 2;

      // Pulsing circles around the border
      final pulseAmount = sin((progress * 4 * pi) + (i * pi / dashCount)) * 3;
      final drawRadius = radius + pulseAmount;

      final x = centerX + drawRadius * cos(angle);
      final y = centerY + drawRadius * sin(angle);

      canvas.drawCircle(Offset(x, y), 1.5 - (offset * 0.8), paint);
    }
  }

  @override
  bool shouldRepaint(WigglePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
