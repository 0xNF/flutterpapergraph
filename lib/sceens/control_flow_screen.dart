// ControlFlowScreen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/main.dart';
import 'package:oauthclient/models/animated_label.dart';
import 'package:oauthclient/models/graph/edge.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/painters/edgespainter.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/widgets/nodes/edge_label/animated_edge_label_widget.dart';
import 'package:oauthclient/widgets/nodes/graphnoderegion.dart';
import 'package:collection/collection.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class Step {
  final String id;
  final String title;

  Step({required this.id, required this.title});
}

/// Core widget that lays out the actual Control Flow Graphs. This widget is responsible for
/// * Containing the actual Graph (i.e. nodes and edges)
/// * Drawing the nodes and edges on the screen with widgets and custompainters
/// * Positioning the Floating Text each node emits over their absolute position (this cannot be done by the node widget itself due to sizing)
/// * Maintaining random seed information for the UsePaper settings to achieve a hand-drawn animation effect
/// * Offering control panel functionality for resetting graph node states, fine tuning the node DataPacket travel speed, etc
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
  // Handles moving a DataPacket across an edge with animations
  late GraphFlowController _flowController;

  // The actual Graph data containing nodes and edges
  late ControlFlowGraph _graph;

  // Filled with callbacks given to us at GraphEventBus subscription time, a method that we can call during dispose() to unsubscribe from our events
  final List<FnUnsub> _fnUnsubFromGraphEventBus = [];

  // Floating text management
  final List<FloatingTextProperties> _nodeFloatingTexts = [];
  late final Map<String, Offset> _nodeScreenPositions = {};

  // Handles the Hand Drawn animation effect
  late AnimationController _drawingController;
  double lastDrawingProgress = 0.0;

  // Holds seed information on a per-graph-edge basis, which lets us give each Graph Edge, when drawn, its own unique seed to achieve a hand-drawn effect. We do this so that no two edges randomize the same way
  final Map<String, int> _graphEdgeSeeds = {};
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

      // Initialize a seed for each edge
      for (final edge in _graph.edges) {
        final seed = widget._paperSettings.newSeed(_graph.edges.indexOf(edge));
        _graphEdgeSeeds[edge.id] = seed;
      }

      _drawingController.addListener(() {
        final currentProgress = _drawingController.value;

        // Detect wrap-around (when progress resets to near 0)
        if (currentProgress < lastDrawingProgress && lastDrawingProgress > 0.5) {
          // Generate new seeds for all edges
          for (final edgeId in _graphEdgeSeeds.keys) {
            _graphEdgeSeeds[edgeId] = widget._paperSettings.newSeed(1);
          }
        }

        lastDrawingProgress = currentProgress;
      });
      _drawingController.repeat();
    }

    _fnUnsubFromGraphEventBus.add(_flowController.dataFlowEventBus.subscribeUnconditional(_onDataFlowEvent));
  }

  @override
  void dispose() {
    _flowController.dispose();
    _controlPanelController.dispose();
    for (final fnUnsub in _fnUnsubFromGraphEventBus) {
      fnUnsub();
    }
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
    } else if (evt is EdgeStateChangedEvent) {
      _onEdgeStateChanged(evt);
    }
  }

  void _onDataExited<T>(DataExitedEvent<T> evt) {
    // Label the edges with the data from the event
    GraphEdgeData? edge = _graph.edges.firstWhereOrNull((c) => c.id == evt.edgeId);
    edge ??= _graph.edges.firstWhereOrNull((c) => c.fromNodeId == evt.fromNodeId && c.toNodeId == evt.intoNodeId);

    if (edge != null) {
      List<int> ids = [];
      for (int i = 0; i < 32; i++) {
        ids.add(r.nextInt(9));
      }
      final animatedLabel = AnimatedLabel(
        id: ids.join(""),
        text: evt.data.labelText,
        edgeLink: EdgeLink(fromId: evt.fromNodeId!, toId: evt.intoNodeId!),
        duration: const Duration(seconds: 2),
        edgeId: edge.id,
      );
      _flowController.flowLabel(animatedLabel, evt.duration ?? const Duration(seconds: 2), evt);
    }
  }

  void _onNodeStateChanged(NodeStateChangedEvent evt) {
    if (evt.oldState == evt.newState) return;
    if (evt.newState == NodeState.disabled) {
      for (final edge in _graph.getEdges(evt.forNodeId!)) {
        edge.edgeState = EdgeState.disabled;
      }
    } else if (evt.oldState == NodeState.disabled && evt.newState != NodeState.disabled) {
      for (final edge in _graph.getEdges(evt.forNodeId!)) {
        // TODO(nf, 01/10/26): only sets to idle, not the others
        edge.edgeState = EdgeState.idle;
      }
    }
    _graph.getNode(evt.forNodeId!)?.setNodeState(evt.newState, notify: false);
  }

  void _onEdgeStateChanged(EdgeStateChangedEvent evt) {
    _graph.edges.firstWhereOrNull((x) => x.id == evt.edgeId)?.edgeState = evt.newState;
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
            String edgeId = "";
            String label = "";
            String data = "";
            bool disbaleEdgeAfter = true;
            bool disableNodeAfter = false;

            if (d == "0") {
              toNodeId = nodeSomeSite;
              edgeId = d!;
              data = d;
              label = "start";
            } else if (d == "2" || d == "4") {
              toNodeId = nodeInstagram;
              if (d == "2") {
                edgeId = "3";
                data = "3";
                label = "login confirmed";
              } else if (d == "4") {
                edgeId = "5";
                data = "5";
                label = "permissions confirmed";
                disableNodeAfter = true;
              }
            }

            final edge = _graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
            if (toNodeId.isNotEmpty && edge != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: toNodeId,
                  edgeId: edgeId,
                  data: DataPacket<String>(labelText: label, actualData: data),
                  disableEdgeAfter: disbaleEdgeAfter,
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
            String edgeId = "";
            String data = "";
            bool disableEdgeAfter = true;
            bool disableNodeAfter = false;
            if (d == "0") {
              toNodeId = nodeInstagram;
              edgeId = "1";
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

            final edge = _graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
            if (toNodeId.isNotEmpty && edge != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: toNodeId,
                  edgeId: edgeId,
                  data: DataPacket<String>(labelText: "redirecting", actualData: data),
                  duration: InheritedStepSettings.of(context).stepSettings.travelDuration,
                  disableEdgeAfter: disableEdgeAfter,
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
            String edgeId = "";
            String label = "";
            String data = "";
            bool disableEdgeAfter = true;
            bool disableNodeAfter = false;
            if (d == "1") {
              edgeId = "2";
              data = "2";
              label = "login";
            } else if (d == "3") {
              edgeId = "4";
              data = "4";
              label = "authorize";
            } else if (d == "5") {
              toNodeId = nodeSomeSite;
              edgeId = "6";
              data = "6";
              label = "permissions confirmed";
              disableNodeAfter = true;
            }

            final edge = _graph.edges.firstWhereOrNull((x) => x.id == edgeId && x.edgeState != EdgeState.disabled);
            if (toNodeId.isNotEmpty && edge != null) {
              _flowController.dataFlowEventBus.emit(
                DataExitedEvent(
                  cameFromNodeId: nid,
                  goingToNodeId: toNodeId,
                  edgeId: edgeId,
                  data: DataPacket<String>(labelText: label, actualData: data),
                  duration: InheritedStepSettings.of(context).stepSettings.travelDuration,
                  disableEdgeAfter: disableEdgeAfter,
                  disableNodeAfter: disableNodeAfter,
                ),
              );
            }
            return ProcessResult(state: disableNodeAfter ? NodeState.disabled : NodeState.selected);
          },
        ),
      ],
      edges: [
        GraphEdgeData(id: '0', fromNodeId: nodeUser, toNodeId: nodeSomeSite, label: '1) initiate', curveBend: -100, labelOffset: Offset(0, -25)),
        GraphEdgeData(id: '1', fromNodeId: nodeSomeSite, toNodeId: nodeInstagram, label: '2) redirect', curveBend: 100, labelOffset: Offset(0, -20)),
        GraphEdgeData(id: '2', fromNodeId: nodeInstagram, toNodeId: nodeUser, label: '3) confirm login', curveBend: 200, labelOffset: Offset(0, 20)),
        GraphEdgeData(id: '3', fromNodeId: nodeUser, toNodeId: nodeInstagram, label: '4) login confirmed', curveBend: 300, labelOffset: Offset(0, 20)),
        GraphEdgeData(id: '4', fromNodeId: nodeInstagram, toNodeId: nodeUser, label: '5) check permissions', curveBend: 450, labelOffset: Offset(0, -20)),
        GraphEdgeData(id: '5', fromNodeId: nodeUser, toNodeId: nodeInstagram, label: '6) permisssions confirmed', curveBend: 700, labelOffset: Offset(0, -20)),
        GraphEdgeData(id: '6', fromNodeId: nodeInstagram, toNodeId: nodeSomeSite, label: '7) ok', curveBend: -150, labelOffset: Offset(0, 20)),
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
            final to = _graph.getOutgoingEdges('node1').sample(1).firstOrNull?.toNodeId;
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
            final to = _graph.getOutgoingEdges('node2').sample(1).firstOrNull?.toNodeId;
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
            final to = _graph.getOutgoingEdges('node3').sample(1).firstOrNull?.toNodeId;
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
            final to = _graph.getOutgoingEdges('node4').sample(1).firstOrNull?.toNodeId;
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
            final to = _graph.getOutgoingEdges('node5').sample(1).firstOrNull?.toNodeId;
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
      edges: [
        GraphEdgeData(id: '0', fromNodeId: 'node1', toNodeId: 'node2', label: 'init', curveBend: 500),
        GraphEdgeData(id: '1', fromNodeId: 'node2', toNodeId: 'node3', label: 'continue'),
        GraphEdgeData(id: '2', fromNodeId: 'node3', toNodeId: 'node4', label: 'yes', curveBend: -200),
        GraphEdgeData(id: '3', fromNodeId: 'node3', toNodeId: 'node5', label: 'no', curveBend: 300),
        GraphEdgeData(id: '4', fromNodeId: 'node4', toNodeId: 'node5', curveBend: -150),
        GraphEdgeData(id: '5', fromNodeId: 'node5', toNodeId: 'node1', curveBend: 700),
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

    // Reset all edges
    for (final edge in _graph.edges) {
      edge.edgeState = EdgeState.idle;
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
                // Edges layer
                AnimatedBuilder(
                  animation: _drawingController,
                  builder: (context, asyncSnapshot) {
                    return CustomPaint(
                      painter: EdgesPainter(
                        graph: _graph,
                        nodeScreenPositions: nodeScreenPositions,
                        controller: _flowController,
                        containerSize: Size(constraints.maxWidth, constraints.maxHeight),
                        usePaper: widget.usePaper,
                        edgeSettings: widget._edgeSettings,
                        paperSettings: widget._paperSettings,
                        drawingProgress: _drawingController.value,
                        edgeSeeds: _graphEdgeSeeds,
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
    GraphEdgeData? edgeData = _graph.edges.firstWhereOrNull((c) => c.id == label.edgeId);
    edgeData ??= _graph.edges.firstWhereOrNull((c) => c.fromNodeId == label.edgeLink.fromId && c.toNodeId == label.edgeLink.toId);

    if (edgeData == null) return const SizedBox.shrink();

    return AnimatedEdgeLabelWidget(
      key: ValueKey(label.id),
      label: label,
      edgeData: edgeData,
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
      final toId = _graph.getOutgoingEdges(nodeId).sample(1).firstOrNull?.toNodeId;
      if (toId != null) {
        _flowController.dataFlowEventBus.emit(
          DataExitedEvent(
            cameFromNodeId: nodeId,
            goingToNodeId: _graph.getOutgoingEdges(nodeId).sample(1).firstOrNull!.toNodeId,
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
                  final edge = _graph.edges.firstOrNull;
                  edge?.edgeState = edge.edgeState == EdgeState.disabled ? EdgeState.idle : EdgeState.disabled;
                },
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text('Cycle Edge 1'),
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
                onPressed: () => _flowLabel(EdgeLink(fromId: 'node1', toId: 'node2')),
                icon: const Icon(Icons.animation, size: 18),
                label: const Text('Flow Label'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  for (final c in _graph.edges) {
                    c.edgeState = EdgeState.idle;
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
  void _flowLabel(EdgeLink edgeLink) {
    _flowController.dataFlowEventBus.emit(
      DataExitedEvent(
        cameFromNodeId: edgeLink.fromId,
        goingToNodeId: edgeLink.toId,
        data: DataPacket(labelText: "f1", actualData: "x"),
      ),
    );
  }
}
