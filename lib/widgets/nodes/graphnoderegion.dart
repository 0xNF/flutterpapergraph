import 'package:flutter/material.dart';
import 'package:oauthclient/controllers/graph_flow_controller.dart';
import 'package:oauthclient/models/graph/graph_data.dart';
import 'package:oauthclient/models/graph/graph_events.dart';
import 'package:oauthclient/src/graph_components/nodes/nodewidget.dart';
import 'package:oauthclient/widgets/nodes/node_process_config.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

const TextStyle floatTextStyle = TextStyle(
  color: Colors.green,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

class GraphNodeRegion extends StatefulWidget {
  final VoidCallback? onTap;
  final GraphNodeData node;
  final GraphFlowController controller;
  final bool usePaper;
  final PaperSettings? paperSettings;
  final void Function(Widget) addFloatingText;

  const GraphNodeRegion({
    super.key,
    this.onTap,
    required this.addFloatingText,
    required this.controller,
    required this.node,
    this.usePaper = false,
    this.paperSettings,
  });

  @override
  State<GraphNodeRegion> createState() => GraphNodeRegionState();
}

class GraphNodeRegionState extends State<GraphNodeRegion> with TickerProviderStateMixin {
  late final FnUnsub fnUnsub;

  @override
  void initState() {
    super.initState();

    // Subscribe to data flow events for this node
    fnUnsub = widget.controller.dataFlowEventBus.subscribe(widget.node.id, _onDataFlowEvent);
  }

  /// Handle data flow events
  void _onDataFlowEvent(GraphEvent event) {
    if (event is DataEnteredEvent && event.intoNodeId == widget.node.id) {
      // _handleDataEntered(event);
    } else if (event is DataExitedEvent<String> && event.fromNodeId == widget.node.id) {
      widget.addFloatingText(Text(event.data.actualData ?? "<n/a>", style: floatTextStyle));
    }
  }

  void onTap() {
    widget.addFloatingText(Text("hi", style: floatTextStyle));
    widget.onTap?.call();
  }

  @override
  void dispose() {
    fnUnsub();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          GraphNodeWidget(
            key: ValueKey(widget.node.id),
            node: widget.node,
            controller: widget.controller,
            onTap: onTap,
            usePaper: widget.usePaper,
            paperSettings: widget.paperSettings,
            addFloatingText: widget.addFloatingText,
            processConfig: NodeProcessConfig(
              process: (input) => widget.node.process(input),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingTextProperties {
  final int id;
  final String nodeId;
  final Animation<Offset> offsetAnimation;
  final Animation<double> opacityAnimation;
  final AnimationController animationController;
  final Widget child;

  FloatingTextProperties({
    required this.id,
    required this.nodeId,
    required this.offsetAnimation,
    required this.opacityAnimation,
    required this.animationController,
    required this.child,
  });
}
