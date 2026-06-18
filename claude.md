# Paper Graph - Claude Context

Animated control-flow graph visualization for Flutter (package name: `oauthclient`). Part of the Gravio HubKit Slingshot project.

## Architecture Summary

See `Architecture.md` for the full system overview. Key points for working in this codebase:

### Graph Construction

Graphs are built with `GraphBuilder` (fluent API). Processors return `RouteDecision` objects; `GraphRouter` handles edge lookup and event emission. Side effects are separated into `ProcessInterceptor` hooks.

- `GraphBuilder` in `lib/models/graph/graph_builder.dart`
- `GraphRouter` + `RouteDecision` in `lib/models/graph/graph_router.dart`
- `ProcessInterceptor` + `InterceptContext` in `lib/models/graph/interceptor.dart`
- Known graphs in `lib/models/knowngraphs/`

### Data Model

- `ControlFlowGraph` extends `ChangeNotifier` -- observable, supports runtime add/remove
- `RoutedGraphNodeData` -- current node type. Processor is a pure routing function.
- `TypedGraphNodeData` -- deprecated, kept for backward compatibility
- `GraphEdgeData` -- edge with visual properties (curveBend, label, arrow position)

### Event System

`GraphEventBus` in `lib/models/graph/graph_events.dart`. Sealed `GraphEvent` hierarchy:
`DataEnteredEvent`, `DataExitedEvent`, `NodeStateChangedEvent`, `EdgeStateChangedEvent`, `ShowWidgetOverlayEvent`, `NodeFloatingTextEvent`, `StopEvent`, `NodeEtherEvent`.

### Rendering Layers

`ControlFlowScreen` in `lib/sceens/control_flow_screen.dart` uses a `Stack`:
1. `EdgesWidget` (CustomPainter: bezier curves)
2. `AnimatedEdgeLabelWidget` (labels traveling along curves)
3. `GraphNodeRegion` > `GraphNodeWidget` (node boxes with state colors)
4. Floating text overlays
5. Modal overlay (login/auth widgets)

### Animation

`GraphFlowController` in `lib/controllers/graph_flow_controller.dart` manages a pool of 10 `AnimationController`s for label flow. Glow and squish animations for nodes.

### Key Patterns

- Node positions are normalized [0,1] and scaled to screen via `LayoutBuilder`
- Edge IDs are auto-generated (`'{counter}_{from}_to_{to}'`) unless explicitly provided
- Interceptors fire based on `onEdgeId` match against the incoming `DataPacket.toEdgeId`
- `InheritedGraphConfigSettings` provides processing/travel durations to processors via `router.processingDuration`

### Adding a New Graph

1. Create file in `lib/models/knowngraphs/`
2. Write a function matching `FnGraphLoad` signature (takes `GraphRouter`, returns `ControlFlowGraph`)
3. Use `GraphBuilder` to define edges, then nodes with processors
4. Add to `KnownGraph` enum and `loadGraph()` switch in `known.dart`

### Event Server

Shelf HTTP server on port 4242 (`lib/server/event_server.dart`). Accepts flatbuffer `RunRequest` at `POST /api/v1/events`. Future: can use `graph.addNode()`/`graph.addEdge()` to mutate graphs from incoming events.
