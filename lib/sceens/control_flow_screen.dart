// ControlFlowScreen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/main.dart';
import 'package:oauthclient/models/animated_label.dart';
import 'package:oauthclient/models/config/config.dart';
import 'package:oauthclient/models/graph/edge.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/models/knowngraphs/known.dart';
import 'package:oauthclient/models/oauth/oauthclient.dart';
import 'package:oauthclient/painters/edgespainter.dart';
import 'package:oauthclient/src/graph_components/graph.dart';
import 'package:oauthclient/src/graph_components/nodes/nodewidget.dart';
import 'package:oauthclient/widgets/misc/authwidget.dart';
import 'package:oauthclient/widgets/misc/loginwidget.dart';
import 'package:oauthclient/widgets/nodes/edge_label/animated_edge_label_widget.dart';
import 'package:oauthclient/widgets/nodes/graphnoderegion.dart';
import 'package:collection/collection.dart';
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
  final KnownGraph whichGraph;

  const ControlFlowScreen({
    super.key,
    this.usePaper = false,
    required this.whichGraph,
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
  late KnownGraph whichGraph;

  // Handles moving a DataPacket across an edge with animations
  late GraphFlowController _flowController;

  // The actual Graph data containing nodes and edges
  late ControlFlowGraph graph;

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

  Widget? _overlayWidget;

  @override
  void initState() {
    super.initState();

    whichGraph = widget.whichGraph;

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
    // Drawing animation controller - only needed for paper style
    _drawingController = AnimationController(
      duration: widget._paperSettings.frameDuration,
      vsync: this,
    );

    _flowController = GraphFlowController(tickerProvider: this);
    graph = _initializeGraph(whichGraph);

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

  ControlFlowGraph _initializeGraph(KnownGraph whichGraph) {
    final loader = loadGraph(whichGraph);
    graph = loader(_flowController, _onUpdateNodeState, () => context, () async {
      if (_autoRepeat && graph.properties.isAutomatic && graph.properties.hasEnd) {
        await Future.delayed(InheritedGraphConfigSettings.of(context).stepSettings.processingDuration + Duration(seconds: 1));
        _resetAll();
        _triggerFlow(graph.startingNodeId!, "0_initiate", "start");
      }
    });

    for (final n in graph.nodes) {
      _nodeScreenPositions[n.id] = n.logicalPosition;
    }

    if (widget.usePaper) {
      _graphEdgeSeeds.clear();
      _drawingController.dispose();
      // Initialize a seed for each edge
      for (final edge in graph.edges) {
        final seed = widget._paperSettings.newSeed(graph.edges.indexOf(edge));
        _graphEdgeSeeds[edge.id] = seed;
      }

      void listener() {
        final currentProgress = _drawingController.value;

        // Detect wrap-around (when progress resets to near 0)
        if (currentProgress < lastDrawingProgress && lastDrawingProgress > 0.5) {
          // Generate new seeds for all edges
          for (final edgeId in _graphEdgeSeeds.keys) {
            _graphEdgeSeeds[edgeId] = widget._paperSettings.newSeed(1);
          }
        }

        lastDrawingProgress = currentProgress;
      }

      _drawingController = AnimationController(
        duration: widget._paperSettings.frameDuration,
        vsync: this,
      );

      _drawingController.addListener(listener);
      _drawingController.repeat();
    }

    return graph;
  }

  void _changeGraph(KnownGraph newGraph) {
    if (newGraph == whichGraph) return;
    // Remove focus from the dropdown
    FocusScope.of(context).unfocus();

    setState(() {
      whichGraph = newGraph;
      _nodeFloatingTexts.clear();
      graph = _initializeGraph(whichGraph);
      InheritedAppTitle.of(context).onTitleChanged(whichGraph.graphTitle);
    });
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
    } else if (evt is ShowWidgetOverlayEvent) {
      _onShowWidgetOverlayEvent(evt);
    }
  }

  Future<void> _onShowWidgetOverlayEvent<T>(ShowWidgetOverlayEvent<T> evt) async {
    await _showOverlay(evt.widget, closeAfter: InheritedGraphConfigSettings.of(context).stepSettings.processingDuration * 2);
    _hideOverlay();
    if (!evt.completer.isCompleted) {
      evt.completer.complete("user@home.arpa" as T);
    }
  }

  void _onDataExited<T>(DataExitedEvent<T> evt) {
    // Label the edges with the data from the event
    GraphEdgeData? edge = graph.edges.firstWhereOrNull((c) => c.id == evt.edgeId);
    edge ??= graph.edges.firstWhereOrNull((c) => c.fromNodeId == evt.fromNodeId && c.toNodeId == evt.intoNodeId);

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
      for (final edge in graph.getEdges(evt.forNodeId!)) {
        edge.edgeState = EdgeState.disabled;
      }
    } else if (evt.oldState == NodeState.disabled && evt.newState != NodeState.disabled) {
      for (final edge in graph.getEdges(evt.forNodeId!)) {
        // TODO(nf, 01/10/26): only sets to idle, not the others
        edge.edgeState = EdgeState.idle;
      }
    }
    graph.getNode(evt.forNodeId!)?.setNodeState(evt.newState, notify: false);
  }

  void _onEdgeStateChanged(EdgeStateChangedEvent evt) {
    graph.edges.firstWhereOrNull((x) => x.id == evt.edgeId)?.edgeState = evt.newState;
  }

  void _onUpdateNodeState(String nodeId, NodeState oldState, NodeState newState, bool notify) {
    _flowController.dataFlowEventBus.emit(NodeStateChangedEvent(oldState: oldState, newState: newState, forNodeId: nodeId));
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
    final control = InheritedGraphConfigSettings.of(context).controlSettings;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: control.showTopAppBar
          ? AppBar(
              title: control.showTitle
                  ? control.canChangeGraph
                        ? DropdownButton<KnownGraph>(
                            value: whichGraph,
                            onChanged: (KnownGraph? newValue) {
                              if (newValue != null) {
                                _changeGraph(newValue);
                              }
                            },
                            items: KnownGraph.values.map<DropdownMenuItem<KnownGraph>>((KnownGraph graph) {
                              return DropdownMenuItem<KnownGraph>(
                                value: graph,
                                child: Text(
                                  graph.graphTitle,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                            underline: Container(), // Remove default underline
                            dropdownColor: Colors.grey[800],
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          )
                        : Text(whichGraph.name)
                  : null,
              elevation: 0,
              backgroundColor: Colors.grey[850],
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Above tablet: expand with max width constraint
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.min(constraints.maxWidth * 0.98, 1600),
                        ),
                        child: _buildGraphContainer(),
                      ),
                    );
                  },
                ),
              ),
              if (control.showBottomAppBar) ...[
                _buildControlPanelToggleButton(),
                _buildAnimatedControlPanel(),
              ],
            ],
          ),
          if (control.showFloatingControls)
            // Floating controls in bottom left
            _buildFloatingControls(),
        ],
      ),
    );
  }

  Widget _buildFloatingControls() {
    final control = InheritedGraphConfigSettings.of(context).controlSettings;
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
                if (control.showAutoRepeat && graph.properties.hasEnd && graph.properties.isAutomatic)
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

                if (control.showReset) ...[
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
    final userNode = graph.nodes.firstWhereOrNull((n) => n.id == fromNode);
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
    for (final edge in graph.edges) {
      edge.edgeState = EdgeState.idle;
    }

    // Reset all nodes
    for (final n in graph.nodes) {
      n.setNodeState(NodeState.unselected, notify: true);
    }

    // Reset flow controller
    _flowController.resetAll();

    // Clear floating texts
    setState(() {
      _nodeFloatingTexts.clear();
      _overlayWidget = null;
    });
  }

  Widget _buildGraphContainer() {
    return LayoutBuilder(
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
                    graph: graph,
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
            for (final node in graph.nodes) _buildNodePosition(node, nodeScreenPositions),

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

            // Overlay Widget
            if (_overlayWidget != null)
              Center(
                child: _overlayWidget!,
              ),
          ],
        );
      },
    );
  }

  Map<String, Offset> _calculateNodePositions(BoxConstraints constraints) {
    final positions = <String, Offset>{};

    for (final node in graph.nodes) {
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
    GraphEdgeData? edgeData = graph.edges.firstWhereOrNull((c) => c.id == label.edgeId);
    edgeData ??= graph.edges.firstWhereOrNull((c) => c.fromNodeId == label.edgeLink.fromId && c.toNodeId == label.edgeLink.toId);

    if (edgeData == null) return const SizedBox.shrink();

    return AnimatedEdgeLabelWidget(
      key: ValueKey(label.id),
      label: label,
      edgeData: edgeData,
      graph: graph,
      nodeScreenPositions: nodeScreenPositions,
      controller: _flowController,
      usePaper: widget.usePaper,
      paperSettings: widget._paperSettings,
    );
  }

  void _onNodeTapped(String nodeId) {
    if (nodeId == "user") {
      graph.nodes.firstWhere((x) => x.id == nodeId).process(DataPacket<String>(actualData: "0_initiate", labelText: "Start"));
    } else {
      _flowController.activateNode(nodeId);
      final to = graph.getOutgoingEdges(graph.startingNodeId!).sample(1).firstWhereOrNull((x) => x.edgeState != EdgeState.disabled)?.toNodeId;
      if (to != null) {
        _flowController.dataFlowEventBus.emit(
          DataExitedEvent(
            cameFromNodeId: nodeId,
            goingToNodeId: graph.getOutgoingEdges(nodeId).sample(1).firstOrNull!.toNodeId,
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
      color: Colors.transparent,
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
    final stepSettings = InheritedGraphConfigSettings.of(context);

    return Container(
      color: Colors.grey[850],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Settings Controls
          _buildSettingsRow(stepSettings),
          if (stepSettings.controlSettings.showDebugSettings) ...[
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
                    final edge = graph.edges.firstOrNull;
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
                    final node = graph.nodes.firstOrNull;
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
                  onPressed: () => _showOverlay(
                    LoginWidget(
                      onConfirm: () async {
                        await Future.delayed(const Duration(milliseconds: 200));
                        _hideOverlay();
                      },
                      onCancel: () async {
                        await Future.delayed(const Duration(milliseconds: 200));
                        _hideOverlay();
                      },
                      siteName: "instagram",
                    ),
                    closeAfter: null,
                  ),
                  icon: const Icon(Icons.animation, size: 18),
                  label: const Text('Show Overlay Login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showOverlay(
                    AuthorizeOAuthClientWidget(
                      onConfirm: () async {
                        await Future.delayed(const Duration(milliseconds: 200));
                        _hideOverlay();
                      },
                      onCancel: () async {
                        await Future.delayed(const Duration(milliseconds: 200));
                        _hideOverlay();
                      },
                      oauthClient: OAuthClient(
                        clientId: "f7383711-e280-4500-9e9f-c0653808d958",
                        name: "somesite.com",
                        redirectUri: "https://somesite.home.arpa",
                        scopes: ["scope1", "read_all_the_things", "offline_access"],
                      ),
                    ),
                    closeAfter: null,
                  ),
                  icon: const Icon(Icons.animation, size: 18),
                  label: const Text('Show Overlay Auth'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    for (final c in graph.edges) {
                      c.edgeState = EdgeState.idle;
                    }
                    for (final n in graph.nodes) {
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
        ],
      ),
    );
  }

  Future<void> _showOverlay(Widget child, {Duration? closeAfter = const Duration(milliseconds: 1000), Completer? completer}) async {
    if (_overlayWidget == null) {
      setState(() {
        _overlayWidget = child;
      });
      if (closeAfter == null) {
        return;
      } else {
        await Future.delayed(closeAfter);
      }
    } else {
      _hideOverlay();
    }
  }

  void _hideOverlay() {
    setState(() {
      _overlayWidget = null;
    });
  }

  Widget _buildSettingsRow(InheritedGraphConfigSettings stepSettingsProvider) {
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
          if (graph.properties.hasTuneableProcessingTime) ...[
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
          ],
          if (graph.properties.hasTuneableTravelTime) ...[
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
}
