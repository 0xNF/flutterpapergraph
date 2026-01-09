import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/animated_label.dart';
import 'package:oauthclient/models/graph/connection.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/painters/connectionspainter.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/connection_label/animated_connection_label_widget.dart';
import 'package:oauthclient/widgets/nodes/graphnoderegion.dart';
import 'package:collection/collection.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class ControlFlowScreen extends StatefulWidget {
  final bool usePaper;
  final PaperSettings _paperSettings;
  final EdgeSettings _edgeSettings;

  const ControlFlowScreen({
    super.key,
    this.usePaper = false,
    PaperSettings? paperSettings,
    EdgeSettings? edgeSettings,
  }) : _paperSettings = paperSettings ?? const PaperSettings(),
       _edgeSettings = edgeSettings ?? const EdgeSettings();

  @override
  State<ControlFlowScreen> createState() => _ControlFlowScreenState();
}

class _ControlFlowScreenState extends State<ControlFlowScreen> with TickerProviderStateMixin {
  late GraphFlowController _flowController;
  late ControlFlowGraph _graph;
  late final FnUnsub _fnUnsub;
  // Floating text management
  final List<FloatingTextProperties> _nodeFloatingTexts = [];
  late final Map<String, Offset> _nodeScreenPositions = {};
  late AnimationController _drawingController;
  final Map<String, int> _connectionSeeds = {};
  double lastDrawingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _flowController = GraphFlowController(tickerProvider: this);
    _graph = _createSampleGraph();
    for (final n in _graph.nodes) {
      _nodeScreenPositions[n.id] = n.logicalPosition;
    }

    if (widget.usePaper) {
      // Drawing animation controller - only needed for paper style
      _drawingController = AnimationController(
        duration: widget._paperSettings.frameDuration,
        vsync: this,
      );

      // Initialize a seed for each connection
      for (final conn in _graph.connections) {
        final seed = widget._paperSettings.newSeed(_graph.connections.indexOf(conn));
        _connectionSeeds[conn.connectionId] = seed;
      }

      _drawingController.addListener(() {
        final currentProgress = _drawingController.value;

        // Detect wrap-around (when progress resets to near 0)
        if (currentProgress < lastDrawingProgress && lastDrawingProgress > 0.5) {
          // Generate new seeds for all connections
          for (final connId in _connectionSeeds.keys) {
            _connectionSeeds[connId] = widget._paperSettings.newSeed(1);
          }
        }

        lastDrawingProgress = currentProgress;
      });
      _drawingController.repeat();
    }

    _fnUnsub = _flowController.dataFlowEventBus.subscribeUnconditional(_onDataFlowEvent);
  }

  @override
  void dispose() {
    _flowController.dispose();
    _fnUnsub();
    super.dispose();
  }

  void _onDataFlowEvent(GraphEvent e) {
    final r = math.Random();
    if (e is DataExitedEvent) {
      // Label the connection with the data from the event
      final connection = _graph.connections.firstWhereOrNull(
        (c) => c.fromId == e.fromNodeId && c.toId == e.intoNodeId,
      );

      if (connection != null) {
        List<int> ids = [];
        for (int i = 0; i < 32; i++) {
          ids.add(r.nextInt(9));
        }
        final label = AnimatedLabel(
          id: ids.join(""),
          text: e.data.labelText,
          connectionId: "${e.fromNodeId}-${e.intoNodeId}",
          duration: const Duration(seconds: 2),
        );
        _flowController.flowLabel(label, e.duration ?? const Duration(seconds: 2));
      }
    }
  }

  ControlFlowGraph _createSampleGraph() {
    final r = math.Random(DateTime.now().millisecondsSinceEpoch);

    Duration selectDurationQuadratic() {
      // Normalize to 0-1
      double normalized = r.nextDouble();

      // Quadratic bias toward median (1000)
      // Creates a peak at 1000
      double biased = 0.5 + (normalized - 0.5) * (1 - (normalized - 0.5).abs());

      // Map to 100-2000 range
      int milliseconds = (100 + biased * 1900).toInt();
      return Duration(milliseconds: milliseconds);
    }

    return ControlFlowGraph(
      nodes: [
        TypedGraphNodeData<String, String>(
          id: 'node1',
          logicalPosition: const Offset(0.1, 0.3),
          contents: NodeContents(stepTitle: "Start"),
          nodeState: NodeState.unselected,
          processor: (d) async {
            await Future.delayed(Duration(milliseconds: 1500));
            final to = _graph.getConnectionsFrom('node1').sample(1).firstOrNull?.toId;
            if (to != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: 'node1',
                  goingToNodeId: to,
                  data: DataPacket<String>(labelText: "f1", actualData: "x"),
                  duration: selectDurationQuadratic(),
                ),
              );
            }
            return ProcessResult(state: NodeState.selected);
          },
        ),
        TypedGraphNodeData<String, String>(
          id: 'node2',
          logicalPosition: const Offset(0.5, 0.2),
          contents: NodeContents(stepTitle: "Process A"),
          nodeState: NodeState.unselected,
          processor: (d) async {
            await Future.delayed(Duration(milliseconds: 1500));
            final to = _graph.getConnectionsFrom('node2').sample(1).firstOrNull?.toId;
            if (to != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: 'node2',
                  goingToNodeId: to,
                  data: DataPacket<String>(labelText: "f2", actualData: "x"),
                  duration: selectDurationQuadratic(),
                ),
              );
            }
            return ProcessResult(state: NodeState.selected);
          },
        ),
        TypedGraphNodeData<String, String>(
          id: 'node3',
          logicalPosition: const Offset(0.5, 0.5),
          contents: NodeContents(stepTitle: "Decision"),
          nodeState: NodeState.unselected,
          processor: (d) async {
            await Future.delayed(Duration(milliseconds: 1500));
            final to = _graph.getConnectionsFrom('node3').sample(1).firstOrNull?.toId;
            if (to != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: 'node3',
                  goingToNodeId: to,
                  data: DataPacket<String>(labelText: "f3", actualData: "x"),
                  duration: selectDurationQuadratic(),
                ),
              );
            }
            return ProcessResult(state: NodeState.selected);
          },
        ),
        TypedGraphNodeData<String, String>(
          id: 'node4',
          logicalPosition: const Offset(0.8, 0.3),
          contents: NodeContents(stepTitle: "Process B"),
          nodeState: NodeState.unselected,
          processor: (d) async {
            await Future.delayed(Duration(milliseconds: 1500));
            final to = _graph.getConnectionsFrom('node4').sample(1).firstOrNull?.toId;
            if (to != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: 'node4',
                  goingToNodeId: to,
                  data: DataPacket<String>(labelText: "f4", actualData: "x"),
                  duration: selectDurationQuadratic(),
                ),
              );
            }
            return ProcessResult(state: NodeState.selected);
          },
        ),
        TypedGraphNodeData<String, String>(
          id: 'node5',
          logicalPosition: const Offset(0.8, 0.7),
          contents: NodeContents(stepTitle: "End"),
          nodeState: NodeState.unselected,
          processor: (d) async {
            // throw Exception("Something Happened");
            await Future.delayed(Duration(milliseconds: 1500));
            final to = _graph.getConnectionsFrom('node5').sample(1).firstOrNull?.toId;
            if (to != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: 'node5',
                  goingToNodeId: to,
                  data: DataPacket(labelText: "f5", actualData: "x"),
                  duration: selectDurationQuadratic(),
                ),
              );
            }
            return ProcessResult(state: NodeState.selected);
          },
        ),
      ],
      connections: [
        GraphConnectionData(fromId: 'node1', toId: 'node2', label: 'init', curveBend: 500),
        GraphConnectionData(fromId: 'node2', toId: 'node3', label: 'continue'),
        GraphConnectionData(fromId: 'node3', toId: 'node4', label: 'yes', curveBend: -200),
        GraphConnectionData(fromId: 'node3', toId: 'node5', label: 'no', curveBend: 300),
        GraphConnectionData(fromId: 'node4', toId: 'node5', curveBend: -150),
        GraphConnectionData(fromId: 'node5', toId: 'node1', curveBend: 700),
      ],
    );
  }

  /// Add floating text that appears above a specific node
  void _addFloatingTextToNode(
    String nodeId,
    Widget floatingWidget, {
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final animationController = AnimationController(
      duration: duration,
      vsync: this,
    );

    final offsetAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -150),
        ).animate(
          CurvedAnimation(parent: animationController, curve: Curves.easeOut),
        );

    final opacityAnimation =
        Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(
          CurvedAnimation(parent: animationController, curve: Curves.easeInExpo),
        );

    final floatingText = FloatingTextProperties(
      id: DateTime.now().millisecondsSinceEpoch,
      nodeId: nodeId,
      offsetAnimation: offsetAnimation,
      opacityAnimation: opacityAnimation,
      animationController: animationController,
      child: floatingWidget,
    );

    setState(() {
      _nodeFloatingTexts.add(floatingText);
    });

    animationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _nodeFloatingTexts.removeWhere((t) => t.id == floatingText.id);
        });
      }
      animationController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Control Flow Animation'),
        elevation: 0,
        backgroundColor: Colors.grey[850],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildGraphContainer(),
          ),
          _buildControlPanel(),
        ],
      ),
    );
  }

  Widget _buildGraphContainer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nodeScreenPositions = _calculateNodePositions(constraints);

            return Stack(
              children: [
                // Connections layer
                AnimatedBuilder(
                  animation: _drawingController,
                  builder: (context, asyncSnapshot) {
                    return CustomPaint(
                      painter: ConnectionsPainter(
                        graph: _graph,
                        nodeScreenPositions: nodeScreenPositions,
                        controller: _flowController,
                        containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                        usePaper: widget.usePaper,
                        edgeSettings: widget._edgeSettings,
                        paperSettings: widget._paperSettings,
                        drawingProgress: _drawingController.value,
                        connectionSeeds: _connectionSeeds,
                      ),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    );
                  },
                ),
                // Animated labels layer
                ListenableBuilder(
                  listenable: _flowController,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        for (final tuple in _flowController.animatingLabels) _buildAnimatedLabel(tuple.$1, nodeScreenPositions),
                      ],
                    );
                  },
                ),
                // Nodes layer
                for (final node in _graph.nodes) _buildNodePosition(node, nodeScreenPositions),

                // Floating text layer (above everything)
                ..._nodeFloatingTexts.map((floatingText) {
                  final nodePosition = nodeScreenPositions[floatingText.nodeId];
                  if (nodePosition == null) return const SizedBox.shrink();

                  return Positioned(
                    left: nodePosition.dx - 75, // Centered relative to node
                    top: nodePosition.dy - 60, // Positioned at node
                    width: 150,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        floatingText.offsetAnimation,
                        floatingText.opacityAnimation,
                      ]),
                      builder: (context, child) {
                        return Transform.translate(
                          offset: floatingText.offsetAnimation.value,
                          child: Opacity(
                            opacity: floatingText.opacityAnimation.value,
                            child: Center(child: floatingText.child),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, Offset> _calculateNodePositions(BoxConstraints constraints) {
    final positions = <String, Offset>{};

    for (final node in _graph.nodes) {
      positions[node.id] = Offset(
        node.logicalPosition.dx * constraints.maxWidth,
        node.logicalPosition.dy * constraints.maxHeight,
      );
    }

    return positions;
  }

  Widget _buildNodePosition(
    GraphNodeData node,
    Map<String, Offset> positions,
  ) {
    final position = positions[node.id];
    if (position == null) return const SizedBox.shrink();

    return Positioned(
      left: position.dx - 50,
      top: position.dy - 50,
      child: GraphNodeRegion(
        node: node,
        controller: _flowController,
        onTap: () => _onNodeTapped(node.id),
        usePaper: widget.usePaper,
        paperSettings: widget._paperSettings,
        addFloatingText: (Widget float) => _addFloatingTextToNode(node.id, float),
      ),
    );
  }

  Widget _buildAnimatedLabel(
    AnimatedLabel label,
    Map<String, Offset> nodeScreenPositions,
  ) {
    final connection = _graph.connections.firstWhereOrNull(
      (c) => c.fromId == label.connectionId.from() && c.toId == label.connectionId.to(),
    );

    if (connection == null) return const SizedBox.shrink();

    return AnimatedConnectionLabelWidget(
      key: ValueKey(label.id),
      label: label,
      connection: connection,
      graph: _graph,
      nodeScreenPositions: nodeScreenPositions,
      controller: _flowController,
      usePaper: widget.usePaper,
      paperSettings: widget._paperSettings,
    );
  }

  void _onNodeTapped(String nodeId) {
    _flowController.activateNode(nodeId);
    _flowController.dataFlowEventBus.emit(
      DataExitedEvent(
        cameFromNodeId: nodeId,
        goingToNodeId: _graph.getConnectionsFrom(nodeId).sample(1).firstOrNull!.toId,
        data: DataPacket(labelText: "f1", actualData: "hi"),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _onNodeTapped('node1'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Activate Node 1'),
          ),
          ElevatedButton.icon(
            onPressed: () => _onNodeTapped('node4'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Activate Node 4'),
          ),
          ElevatedButton.icon(
            onPressed: () => _flowLabel('node1-node2'),
            icon: const Icon(Icons.animation),
            label: const Text('Flow Label'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              _flowController.resetAll();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  var counter = 0;
  void _flowLabel(ConnectionId connectionId) {
    _flowController.dataFlowEventBus.emit(
      DataExitedEvent(
        cameFromNodeId: connectionId.from(),
        goingToNodeId: connectionId.to(),
        data: DataPacket(labelText: "f1", actualData: "x"),
      ),
    );
  }
}
