import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oauthclient/src/graph_components/graph.dart';

class GraphNode extends StatefulWidget {
  final NodeState blockState;
  final NodeContents stepData;
  final VoidCallback? onTap;

  const GraphNode({super.key, required this.blockState, required this.stepData, this.onTap});

  @override
  State<GraphNode> createState() => _GraphNodeState();
}

class _GraphNodeState extends State<GraphNode> with TickerProviderStateMixin {
  late AnimationController _vaporwaveController;
  late AnimationController _squishController;
  late Animation<double> _squishAnimation;

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
  }

  @override
  void dispose() {
    _vaporwaveController.dispose();
    _squishController.dispose();
    super.dispose();
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

  Color blockState2color(NodeState blockState) {
    return switch (blockState) {
      NodeState.unselected => Colors.grey,
      NodeState.selected => Colors.green,
      NodeState.inProgress => Colors.greenAccent,
      NodeState.error => Colors.red,
      NodeState.disabled => Colors.yellow,
    };
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    // onTap: _onTap,
    onTapDown: (_) => _onMouseDown(),
    onTapUp: (_) => _onMouseUp(),
    child: AnimatedBuilder(
      animation: Listenable.merge([_vaporwaveController, _squishController]),
      builder: (context, child) {
        final squishValue = _squishAnimation.value;
        final squishX = 1 + (squishValue * 0.1);
        final squishY = 1 - (squishValue * 0.3);
        return Transform.scale(
          scaleX: squishX,
          scaleY: squishY,
          child: Container(
            height: 150,
            width: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: widget.blockState == NodeState.inProgress
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
              border: Border.all(
                color: widget.blockState == NodeState.inProgress ? Colors.transparent : blockState2color(widget.blockState),
                width: 5,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Transform.scale(
                scaleX: 1 / squishX,
                scaleY: 1 / squishY,
                child: Center(
                  child: Text(
                    widget.stepData.stepTitle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
