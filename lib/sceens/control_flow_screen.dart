import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/scheduler.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/main.dart';
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
  final NodeSettings _nodeSettings;

  const ControlFlowScreen({
    super.key,
    this.usePaper = false,
    PaperSettings? paperSettings,
    EdgeSettings? edgeSettings,
    NodeSettings? nodeSettings,
  }) : _paperSettings = paperSettings ?? const PaperSettings(),
       _edgeSettings = edgeSettings ?? const EdgeSettings(),
       _nodeSettings = nodeSettings ?? const NodeSettings();

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
  final r = math.Random();
  // Control Panel Animation
  late AnimationController _controlPanelController;
  late Animation<double> _controlPanelAnimation;
  bool _isControlPanelOpen = false;
  // Auto Repeat State
  bool _autoRepeat = false;
  Timer? _autoRepeatTimer;

  @override
  void initState() {
    super.initState();
    _graph = _simpleAuthGraph1();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      InheritedAppTitle.of(context).onTitleChanged("OAuth Flow Overview");
    });

    // Control Panel Animation Setup
    _controlPanelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlPanelAnimation = CurvedAnimation(
      parent: _controlPanelController,
      curve: Curves.easeInOut,
    );

    _flowController = GraphFlowController(tickerProvider: this);

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
          for (final connectionId in _connectionSeeds.keys) {
            _connectionSeeds[connectionId] = widget._paperSettings.newSeed(1);
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
    _controlPanelController.dispose();
    _fnUnsub();
    super.dispose();
  }

  void _toggleControlPanel() {
    setState(() {
      _isControlPanelOpen = !_isControlPanelOpen;
      if (_isControlPanelOpen) {
        _controlPanelController.forward();
      } else {
        _controlPanelController.reverse();
      }
    });
  }

  void _onDataFlowEvent(GraphEvent evt) {
    if (evt is DataExitedEvent) {
      _onDataExited(evt);
    } else if (evt is NodeStateChangedEvent) {
      _onNodeStateChanged(evt);
    } else if (evt is ConnectionStateChangedEvent) {
      _onConnectionStateChanged(evt);
    }
  }

  void _onDataExited<T>(DataExitedEvent<T> evt) {
    // Label the connection with the data from the event
    GraphConnectionData? conn = _graph.connections.firstWhereOrNull((c) => c.connectionId == evt.connectionId);
    conn ??= _graph.connections.firstWhereOrNull((c) => c.fromId == evt.fromNodeId && c.toId == evt.intoNodeId);

    if (conn != null) {
      List<int> ids = [];
      for (int i = 0; i < 32; i++) {
        ids.add(r.nextInt(9));
      }
      final animatedLabel = AnimatedLabel(
        id: ids.join(""),
        text: evt.data.labelText,
        connectionLink: "${evt.fromNodeId}-${evt.intoNodeId}",
        duration: const Duration(seconds: 2),
        connectionId: conn.connectionId,
      );
      _flowController.flowLabel(animatedLabel, evt.duration ?? const Duration(seconds: 2), evt);
    }
  }

  void _onNodeStateChanged(NodeStateChangedEvent evt) {
    if (evt.oldState == evt.newState) return;
    if (evt.newState == NodeState.disabled) {
      for (final conn in _graph.getConnectionsFor(evt.forNodeId!)) {
        conn.connectionState = ConnectionState.disabled;
      }
    } else if (evt.oldState == NodeState.disabled && evt.newState != NodeState.disabled) {
      for (final conn in _graph.getConnectionsFor(evt.forNodeId!)) {
        // TODO(nf, 01/10/26): only sets to idle, not the others
        conn.connectionState = ConnectionState.idle;
      }
    }
    _graph.getNode(evt.forNodeId!)?.setNodeState(evt.newState, notify: false);
  }

  void _onConnectionStateChanged(ConnectionStateChangedEvent evt) {
    _graph.connections.firstWhereOrNull((x) => x.connectionId == evt.connectionId)?.connectionState = evt.newState;
  }

  void onUpdateNodeState(String nodeId, NodeState oldState, NodeState newState, bool notify) {
    _flowController.dataFlowEventBus.emit(NodeStateChangedEvent(oldState: oldState, newState: newState, forNodeId: nodeId));
  }

  ControlFlowGraph _simpleAuthGraph1() {
    const nodeUser = 'user';
    const nodeSomeSite = 'somesite.com';
    const nodeInstagram = 'instagram';

    return ControlFlowGraph(
      nodes: [
        TypedGraphNodeData<String, String>(
          id: nodeUser,
          logicalPosition: const Offset(0.1, 0.3),
          contents: NodeContents(stepTitle: "User"),
          nodeState: NodeState.unselected,
          onUpdateState: (o, n) => onUpdateNodeState(nodeUser, o, n, true),
          processor: (d) async {
            const nid = nodeUser;
            await Future.delayed(InheritedStepSettings.of(context).stepSettings.processingDuration);
            String toNodeId = "";
            String connectionId = "";
            String label = "";
            String data = "";
            bool disableConnAfter = true;
            bool disableNodeAfter = false;

            if (d == "0") {
              toNodeId = nodeSomeSite;
              connectionId = d!;
              data = d;
              label = "start";
            } else if (d == "2" || d == "4") {
              toNodeId = nodeInstagram;
              if (d == "2") {
                connectionId = "3";
                data = "3";
                label = "login confirmed";
              } else if (d == "4") {
                connectionId = "5";
                data = "5";
                label = "permissions confirmed";
                disableNodeAfter = true;
              }
            }

            final conn = _graph.connections.firstWhereOrNull((x) => x.connectionId == connectionId && x.connectionState != ConnectionState.disabled);
            if (toNodeId.isNotEmpty && conn != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: toNodeId,
                  connectionId: connectionId,
                  data: DataPacket<String>(labelText: label, actualData: data),
                  disableConnectionAfter: disableConnAfter,
                  disableNodeAfter: disableNodeAfter,
                  duration: InheritedStepSettings.of(context).stepSettings.travelDuration,
                ),
              );
            }
            return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
          },
        ),
        TypedGraphNodeData<String, String>(
          id: nodeSomeSite,
          logicalPosition: const Offset(0.5, 0.2),
          contents: NodeContents(stepTitle: "SomeSite.com", textStyle: TextStyle(fontSize: 10)),
          nodeState: NodeState.unselected,
          onUpdateState: (o, n) => onUpdateNodeState(nodeSomeSite, o, n, true),
          processor: (d) async {
            const nid = nodeSomeSite;
            await Future.delayed(InheritedStepSettings.of(context).stepSettings.processingDuration);

            String toNodeId = "";
            String connectionId = "";
            String data = "";
            bool disableConnAfter = true;
            bool disableNodeAfter = false;
            if (d == "0") {
              toNodeId = nodeInstagram;
              connectionId = "1";
              data = "1";
            } else if (d == "6") {
              disableNodeAfter = true;
              if (_autoRepeat) {
                await Future.delayed(InheritedStepSettings.of(context).stepSettings.processingDuration + Duration(seconds: 1));
                _resetAll();
                _triggerFlow(nodeUser, "0", "start");
                return ProcessResult(state: NodeState.unselected);
              }
            } else {
              return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
            }

            final conn = _graph.connections.firstWhereOrNull((x) => x.connectionId == connectionId && x.connectionState != ConnectionState.disabled);
            if (toNodeId.isNotEmpty && conn != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: toNodeId,
                  connectionId: connectionId,
                  data: DataPacket<String>(labelText: "redirecting", actualData: data),
                  duration: InheritedStepSettings.of(context).stepSettings.travelDuration,
                  disableConnectionAfter: disableConnAfter,
                  disableNodeAfter: disableNodeAfter,
                ),
              );
            }
            return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
          },
        ),
        TypedGraphNodeData<String, String>(
          id: 'instagram',
          logicalPosition: const Offset(0.8, 0.3),
          contents: NodeContents(stepTitle: "instagram", textStyle: TextStyle(fontSize: 10)),
          nodeState: NodeState.unselected,
          onUpdateState: (o, n) => onUpdateNodeState(nodeInstagram, o, n, true),
          processor: (d) async {
            const nid = nodeInstagram;
            await Future.delayed(InheritedStepSettings.of(context).stepSettings.processingDuration);

            String toNodeId = nodeUser;
            String connectionId = "";
            String label = "";
            String data = "";
            bool disableConnAfter = true;
            bool disableNodeAfter = false;
            if (d == "1") {
              connectionId = "2";
              data = "2";
              label = "login";
            } else if (d == "3") {
              connectionId = "4";
              data = "4";
              label = "authorize";
            } else if (d == "5") {
              toNodeId = nodeSomeSite;
              connectionId = "6";
              data = "6";
              label = "permissions confirmed";
              disableNodeAfter = true;
            }

            final conn = _graph.connections.firstWhereOrNull((x) => x.connectionId == connectionId && x.connectionState != ConnectionState.disabled);
            if (toNodeId.isNotEmpty && conn != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: toNodeId,
                  connectionId: connectionId,
                  data: DataPacket<String>(labelText: label, actualData: data),
                  duration: InheritedStepSettings.of(context).stepSettings.travelDuration,
                  disableConnectionAfter: disableConnAfter,
                  disableNodeAfter: disableNodeAfter,
                ),
              );
            }
            return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
          },
        ),
      ],
      connections: [
        GraphConnectionData(connectionId: '0', fromId: nodeUser, toId: nodeSomeSite, label: '1) initiate', curveBend: -100, labelOffset: Offset(0, -25)),
        GraphConnectionData(connectionId: '1', fromId: nodeSomeSite, toId: nodeInstagram, label: '2) redirect', curveBend: 100, labelOffset: Offset(0, -20)),
        GraphConnectionData(connectionId: '2', fromId: nodeInstagram, toId: nodeUser, label: '3) confirm login', curveBend: 200, labelOffset: Offset(0, 20)),
        GraphConnectionData(connectionId: '3', fromId: nodeUser, toId: nodeInstagram, label: '4) login confirmed', curveBend: 300, labelOffset: Offset(0, 20)),
        GraphConnectionData(connectionId: '4', fromId: nodeInstagram, toId: nodeUser, label: '5) check permissions', curveBend: 450, labelOffset: Offset(0, -20)),
        GraphConnectionData(connectionId: '5', fromId: nodeUser, toId: nodeInstagram, label: '6) permisssions confirmed', curveBend: 700, labelOffset: Offset(0, -20)),
        GraphConnectionData(connectionId: '6', fromId: nodeInstagram, toId: nodeSomeSite, label: '7) ok', curveBend: -150, labelOffset: Offset(0, 20)),
      ],
    );
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
        GraphConnectionData(connectionId: '0', fromId: 'node1', toId: 'node2', label: 'init', curveBend: 500),
        GraphConnectionData(connectionId: '1', fromId: 'node2', toId: 'node3', label: 'continue'),
        GraphConnectionData(connectionId: '2', fromId: 'node3', toId: 'node4', label: 'yes', curveBend: -200),
        GraphConnectionData(connectionId: '3', fromId: 'node3', toId: 'node5', label: 'no', curveBend: 300),
        GraphConnectionData(connectionId: '4', fromId: 'node4', toId: 'node5', curveBend: -150),
        GraphConnectionData(connectionId: '5', fromId: 'node5', toId: 'node1', curveBend: 700),
      ],
    );
  }

  /// Add floating text that appears above a specific node
  void _addFloatingTextToNode(
    String nodeId,
    Widget floatingWidget, {
    Duration? duration,
  }) {
    duration = duration ?? widget._nodeSettings.floatingTextDurationDefault;
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
        title: Text(
          InheritedAppTitle.of(context).title,
        ),
        elevation: 0,
        backgroundColor: Colors.grey[850],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _buildGraphContainer(),
              ),
              _buildControlPanelToggleButton(),
              _buildAnimatedControlPanel(),
            ],
          ),
          // Floating controls in bottom left
          _buildFloatingControls(),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[850],
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blueAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auto Repeat Checkbox
                InkWell(
                  onTap: () {
                    setState(() {
                      _autoRepeat = !_autoRepeat;
                      if (!_autoRepeat) {
                        _stopAutoRepeat();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _autoRepeat,
                            onChanged: (value) {
                              setState(() {
                                _autoRepeat = value ?? false;
                                if (!_autoRepeat) {
                                  _stopAutoRepeat();
                                }
                              });
                            },
                            activeColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Auto Repeat',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Reset Button
                SizedBox(
                  child: ElevatedButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _stopAutoRepeat() {
    _autoRepeatTimer?.cancel();
    _autoRepeatTimer = null;
  }

  void _triggerFlow<T>(String fromNode, T actualData, String label) {
    // Trigger a flow animation
    // You can customize this to trigger whatever flow you want
    final userNode = _graph.nodes.firstWhereOrNull((n) => n.id == fromNode);
    if (userNode != null) {
      userNode.process(
        DataPacket(
          actualData: actualData,
          labelText: label,
        ),
      );
    }
  }

  void _resetAll() {
    // Stop auto repeat if running
    if (!_autoRepeat) {
      _stopAutoRepeat();
    }

    // Reset all connections
    for (final c in _graph.connections) {
      c.connectionState = ConnectionState.idle;
    }

    // Reset all nodes
    for (final n in _graph.nodes) {
      n.setNodeState(NodeState.unselected, notify: true);
    }

    // Reset flow controller
    _flowController.resetAll();

    // Clear floating texts
    setState(() {
      _nodeFloatingTexts.clear();
    });
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
        nodeSettings: const NodeSettings(),
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
    GraphConnectionData? connection = _graph.connections.firstWhereOrNull((c) => c.connectionId == label.connectionId);
    connection ??= _graph.connections.firstWhereOrNull((c) => c.fromId == c.connectionLink.from() && c.toId == c.connectionLink.to());

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
    if (nodeId == "user") {
      _graph.nodes.firstWhere((x) => x.id == nodeId).process(DataPacket<String>(actualData: "0", labelText: "Start"));
    } else {
      _flowController.activateNode(nodeId);
      final toId = _graph.getConnectionsFrom(nodeId).sample(1).firstOrNull?.toId;
      if (toId != null) {
        _flowController.dataFlowEventBus.emit(
          DataExitedEvent(
            cameFromNodeId: nodeId,
            goingToNodeId: _graph.getConnectionsFrom(nodeId).sample(1).firstOrNull!.toId,
            data: DataPacket(labelText: "f1", actualData: "hi"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildControlPanelToggleButton() {
    return Container(
      width: double.infinity,
      color: Colors.grey[900],
      child: Center(
        child: AnimatedBuilder(
          animation: _controlPanelAnimation,
          builder: (context, child) {
            return IconButton(
              onPressed: _toggleControlPanel,
              icon: AnimatedRotation(
                turns: _isControlPanelOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.keyboard_arrow_up),
              ),
              tooltip: _isControlPanelOpen ? 'Hide Controls' : 'Show Controls',
              iconSize: 32,
              color: Colors.white70,
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedControlPanel() {
    return SizeTransition(
      sizeFactor: _controlPanelAnimation,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _controlPanelAnimation,
        child: _buildControlPanelContent(),
      ),
    );
  }

  Widget _buildControlPanelContent() {
    final stepSettings = InheritedStepSettings.of(context);

    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Settings Controls
          _buildSettingsRow(stepSettings),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 8),
          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final conn = _graph.connections.firstOrNull;
                  conn?.connectionState = conn.connectionState == ConnectionState.disabled ? ConnectionState.idle : ConnectionState.disabled;
                },
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text('Cycle Connection 1'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final node = _graph.nodes.firstOrNull;
                  if (node?.nodeState == NodeState.disabled) {
                    node?.setNodeState(NodeState.unselected);
                  } else {
                    node?.setNodeState(NodeState.disabled);
                  }
                },
                icon: const Icon(Icons.circle, size: 18),
                label: const Text('Cycle Node 1'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _flowLabel('node1-node2'),
                icon: const Icon(Icons.animation, size: 18),
                label: const Text('Flow Label'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  for (final c in _graph.connections) {
                    c.connectionState = ConnectionState.idle;
                  }
                  for (final n in _graph.nodes) {
                    n.setNodeState(NodeState.unselected, notify: true);
                  }
                  _flowController.resetAll();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset All'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(InheritedStepSettings stepSettingsProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Colors.white70),
          const SizedBox(width: 16),
          const Text(
            'Global Settings:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _buildDurationControl(
              label: 'Processing Duration',
              value: stepSettingsProvider.stepSettings.processingDuration,
              onChanged: (newDuration) {
                stepSettingsProvider.onSettingsChanged(
                  stepSettingsProvider.stepSettings.copyWith(
                    processingDuration: newDuration,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildDurationControl(
              label: 'Travel Duration',
              value: stepSettingsProvider.stepSettings.travelDuration,
              onChanged: (newDuration) {
                stepSettingsProvider.onSettingsChanged(
                  stepSettingsProvider.stepSettings.copyWith(
                    travelDuration: newDuration,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationControl({
    required String label,
    required Duration value,
    required ValueChanged<Duration> onChanged,
  }) {
    final seconds = value.inMilliseconds / 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              '${seconds.toStringAsFixed(1)}s',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: seconds.clamp(0.1, 10.0),
          min: 0.1,
          max: 10.0,
          divisions: 99,
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.grey[700],
          onChanged: (newValue) {
            onChanged(Duration(milliseconds: (newValue * 1000).round()));
          },
        ),
      ],
    );
  }

  var counter = 0;
  void _flowLabel(ConnectionLink connectionLink) {
    _flowController.dataFlowEventBus.emit(
      DataExitedEvent(
        cameFromNodeId: connectionLink.from(),
        goingToNodeId: connectionLink.to(),
        data: DataPacket(labelText: "f1", actualData: "x"),
      ),
    );
  }
}
