# Paper Graph

Animated control-flow graph visualization for Flutter. Nodes process data packets that travel along bezier-curved edges as animated labels, with configurable routing, side-effect hooks, and optional hand-drawn rendering.

![demo.gif](demo.gif)

## Quick Start

```bash
flutter pub get
flutter run
```

The app starts an HTTP event server on port 4242 and launches the graph visualization. Select a graph from the dropdown in the top bar.

## Building Graphs

Graphs are built with a fluent `GraphBuilder` API. Processors are pure routing functions that return a `RouteDecision`; the `GraphRouter` handles edge lookup and event emission. Side effects (UI overlays, floating text) are separated into `ProcessInterceptor` hooks.

```dart
ControlFlowGraph myGraph(GraphRouter router, FnNodeStateCallback onUpdateNodeState,
    FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
  final builder = GraphBuilder()
    ..startAt('a')
    ..properties(isAutomatic: true, hasEnd: true)
    ..edge('a', 'b', label: 'go', curveBend: -100)
    ..edge('b', 'a', label: 'back', curveBend: 100)
    ..node<String, String>('a', position: Offset(0.2, 0.5), title: "Start",
      processor: (packet, router) async {
        await Future.delayed(router.processingDuration);
        return RouteDecision.toNode(toNodeId: 'b', label: "hello");
      })
    ..node<String, String>('b', position: Offset(0.8, 0.5), title: "End",
      processor: (packet, router) async {
        onEnd();
        return RouteDecision.terminal();
      });
  return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
}
```

Register the graph in the `KnownGraph` enum in `lib/models/knowngraphs/known.dart` and add its case to the `loadGraph()` switch.

## Included Graphs

| Graph | Description |
|-------|-------------|
| Racers | Random walk through 5 nodes in an endless loop |
| OAuth Flow (user perspective) | Sequential auth flow with login and permission overlays |
| OAuth Flow (access token) | Token acquisition with conditional routing |
| ACR (Addon Component Runner) | Hypervisor dispatches to worker pools with load balancing |

## Dynamic Graphs

Graphs are observable (`ChangeNotifier`). Nodes and edges can be added or removed at runtime and the UI updates automatically:

```dart
graph.addNode(RoutedGraphNodeData(...));
graph.addEdge(GraphEdgeData(...));
graph.removeNode('nodeId');
graph.removeEdge('edgeId');
```

## Architecture

See [Architecture.md](Architecture.md) for a detailed system overview.

## Project Structure

```
lib/
  main.dart                      Entry point
  controllers/                   GraphFlowController (animation orchestrator)
  models/
    graph/                       Core: data model, router, builder, events, interceptors
    knowngraphs/                 Predefined graph definitions
    config/                      InheritedWidget settings
  painters/                      CustomPainters (edges, hand-drawn rectangles)
  sceens/                        ControlFlowScreen (main graph UI)
  server/                        Shelf HTTP event server
  src/graph_components/          Node and edge widgets
  widgets/                       Node regions, animated labels, overlays, paper effects
  utils/                         Bezier math, paper drawing utilities
```
