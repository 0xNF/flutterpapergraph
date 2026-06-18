# Architecture

Paper Graph is a Flutter application for building, visualizing, and animating control-flow graphs. Nodes process data packets that travel along edges as animated labels, with routing decisions, side-effect hooks, and graph mutations all handled through dedicated subsystems.

## Directory Layout

```
lib/
  main.dart                         App entry point, starts EventServer + ControlFlowApp
  controllers/
    graph_flow_controller.dart      Animation orchestrator (label flow, glow, squish)
    graph_mutation_controller.dart  Dynamic node/edge creation with routing strategies
  models/
    animated_label.dart             Data for labels that travel along edges
    config/
      config.dart                   InheritedWidget settings (Step, Control, Edge, Node, Paper)
    graph/
      graph_data.dart               Core data model: ControlFlowGraph, GraphNodeData, GraphEdgeData
      graph_router.dart             Routing engine: GraphRouter + RouteDecision
      graph_builder.dart            Fluent builder API for constructing graphs
      graph_events.dart             Event bus + sealed event hierarchy
      dynamic_routing.dart          DynamicRoutingStrategy enum + processor factory
      interceptor.dart              Side-effect hooks: ProcessInterceptor, InterceptContext
      edge.dart                     Minimal EdgeLink (fromId, toId) for animated labels
    knowngraphs/
      known.dart                    KnownGraph enum, FnGraphLoad typedef, loadGraph()
      racers.dart                   Demo: random walk through 5 nodes
      simple_auth_graph.dart        OAuth user-perspective flow with UI overlays
      auth_2_access.dart            OAuth access-token acquisition flow
      acr.dart                      Addon Component Runner: hypervisor + worker pools
      new_graph.dart                Blank graph with UUID, forward-routing start node
    oauth/
      oauthclient.dart              OAuthClient model for demo overlays
  painters/
    edgespainter.dart               CustomPainter: cubic bezier edges, arrowheads, labels
    paper.dart                      HandDrawnRectanglePainter: sketchy rectangle borders
  sceens/
    control_flow_screen.dart        Main screen: graph layout, event handling, control panel
  server/
    event_server.dart               Shelf HTTP server on :4242, flatbuffer ingestion
  src/graph_components/
    graph.dart                      NodeState + NodeContents enums/classes
    nodes/
      nodewidget.dart               Individual node widget (animations, state colors, squish)
      edgeswidget.dart              Stateful widget wrapping EdgesPainter + drag interaction
    graphcontainer/
      graphcontainer.dart           (Legacy) graph container widget
    graphnode.dart                   (Legacy) standalone graph node
    splineconnection.dart           (Legacy) spline connection model
  utils/
    bezier/
      bezier.dart                   BezierUtils: evaluateCubicBezier, evaluateCubicBezierTangent
    paper/
      paper.dart                    Hand-drawn line utilities
  widgets/
    nodes/
      graphnoderegion.dart          Node container: wraps GraphNodeWidget, subscribes to events
      node_process_config.dart      ProcessResult, NodeProcessConfig
      edge_label/
        animated_edge_label_widget.dart   Positions labels along bezier curves during animation
    paper/
      paper.dart                    InheritedPaperSettings, PaperSettings
      jitteredtext.dart             Text with random jitter for hand-drawn effect
      jitteredwidget.dart           Generic jittered widget wrapper
      paperbutton.dart              Hand-drawn style button
    misc/
      authwidget.dart               OAuth authorization grant overlay
      loginwidget.dart              Login prompt overlay
  flatbuffers/
    acr_generated.dart              Generated flatbuffer types (RunRequest, ComponentResult, etc.)
```

## Core Subsystems

### 1. Graph Data Model (`models/graph/graph_data.dart`)

`ControlFlowGraph` extends `ChangeNotifier`. It holds nodes, edges, and graph properties. UI layers listen to it for dynamic add/remove of nodes and edges at runtime.

```
ControlFlowGraph (ChangeNotifier)
  _nodes: List<GraphNodeData>    -- mutable, notifies on add/remove
  _edges: List<GraphEdgeData>    -- mutable, notifies on add/remove
  startingNodeId: String?
  properties: GraphProperties
  +addNode(), removeNode(), addEdge(), removeEdge()
  +getNode(), getOutgoingEdges(), getIncomingEdges(), getEdges()
```

**GraphNodeData** is the abstract base. Two concrete implementations:

- **RoutedGraphNodeData** (current) -- processor returns a `RouteDecision`; routing is executed by `GraphRouter`. Side effects are handled by `ProcessInterceptor` hooks that run before the processor.
- **TypedGraphNodeData** (deprecated) -- processor manually emits `DataExitedEvent` with full routing details. Kept for backward compatibility.

**GraphEdgeData** stores the visual and structural properties of an edge: source/target node IDs, label, curve bend, arrow position, and edge state (idle, inProgress, error, disabled).

**GraphProperties** is a set of feature flags per graph: `isAutomatic`, `hasEnd`, `hasTuneableTravelTime`, `hasTuneableProcessingTime`, `canStepDebug`, `canShowCurrentState`.

### 2. Routing (`models/graph/graph_router.dart`)

`GraphRouter` decouples routing mechanics from business logic. Processors return a `RouteDecision` expressing intent; the router handles edge lookup, event emission, and disable-after-processing flags.

```
                      DataPacket arrives at node
                              |
                    [Run interceptors in order]
                              |
                   interceptor fires? ──yes──> execute side effect
                              |                     |
                              |              ContinueResult: modify packet, continue
                              |              ShortCircuitResult: skip processor, route immediately
                              |
                    [Run processor]
                              |
                    RouteDecision returned
                              |
              ┌───────────────┼───────────────┐
              |               |               |
         .terminal()     .toNode()      RouteDecision()
         (no routing)   (router picks   (explicit edge ID)
                         first edge)
              |               |               |
              v               v               v
         ProcessResult   GraphRouter.executeRoute()
                              |
                        DataExitedEvent emitted
                              |
                     GraphFlowController.flowLabel()
                              |
                        [Animation runs]
                              |
                     DataEnteredEvent at target node
                              |
                        cycle repeats
```

**RouteDecision** constructors:
- `RouteDecision(toNodeId, edgeId, ...)` -- route along a specific edge
- `RouteDecision.toNode(toNodeId, ...)` -- router finds the first enabled edge between nodes
- `RouteDecision.terminal(resultingNodeState)` -- stop; no data emitted

**GraphRouter** convenience methods:
- `findEdge(fromNodeId, toNodeId)` -- first enabled edge between two nodes
- `findEdgeById(edgeId)` -- edge by ID, if enabled
- `randomOutgoingEdge(fromNodeId, ...)` -- pick a random enabled outgoing edge
- `processingDuration` / `travelDuration` -- read from `InheritedGraphConfigSettings`

### 3. Interceptors (`models/graph/interceptor.dart`)

Interceptors separate side effects from routing logic. They run before the processor and can modify the data packet or short-circuit the processor entirely.

```dart
ProcessInterceptor(
  onEdgeId: 'confirm_login',          // fires when data arrives via this edge
  execute: (packet, ctx) async {
    final user = await ctx.showOverlay<String>(LoginWidget(...));
    ctx.showFloatingText(Text(user));
    return InterceptResult.continueWith(packet);
  },
)
```

**InterceptContext** provides:
- `showOverlay<T>(Widget)` -- display an overlay widget, await user interaction (replaces manual Completer + ShowWidgetOverlayEvent boilerplate)
- `showFloatingText(Text)` -- emit floating text above the node
- `processingDuration` / `travelDuration` -- inherited settings
- `eventBus` -- direct access to `GraphEventBus` for advanced use

**InterceptResult** (sealed):
- `InterceptResult.continueWith(packet)` -- pass (possibly modified) packet to the processor
- `InterceptResult.shortCircuit(RouteDecision)` -- skip the processor, route immediately

### 4. Graph Builder (`models/graph/graph_builder.dart`)

Fluent API for constructing graphs. Edges are defined first (so their auto-generated IDs can be referenced by interceptors), then nodes.

```dart
final builder = GraphBuilder()
  ..startAt('user')
  ..properties(isAutomatic: true, hasEnd: true);

final loginEdge = builder.edge('server', 'user', id: 'login', label: 'login');
builder.edge('user', 'server', label: 'response');

builder.node<String, String>('user', position: Offset(0.1, 0.3), title: "User",
  interceptors: [ProcessInterceptor(onEdgeId: loginEdge, ...)],
  processor: (packet, router) async => RouteDecision.toNode(toNodeId: 'server'),
);

final graph = builder.build(router: router, onUpdateNodeState: callback);
```

Edge IDs are auto-generated as `'{counter}_{from}_to_{to}'` unless explicitly provided. Only edges referenced by interceptors need explicit IDs.

### 5. Event System (`models/graph/graph_events.dart`)

`GraphEventBus` (extends `ChangeNotifier`) is a pub/sub system for graph events. Nodes subscribe by ID; unconditional listeners receive all events.

**Event hierarchy** (sealed `GraphEvent`):

| Event | Trigger | Effect |
|-------|---------|--------|
| `DataEnteredEvent` | Label animation completes | Target node's `process()` is called |
| `DataExitedEvent` | Processor/router emits | `GraphFlowController.flowLabel()` starts animation |
| `NodeStateChangedEvent` | Node state changes | UI updates node color/border |
| `EdgeStateChangedEvent` | Edge state changes | UI updates edge color |
| `ShowWidgetOverlayEvent` | Interceptor/processor | Screen shows modal overlay |
| `NodeFloatingTextEvent` | Interceptor/processor | Floating text appears above node |
| `StopEvent` | Reset or halt | All nodes stop processing |
| `NodeEtherEvent` | Node completes without routing | Terminal event |

### 6. Animation (`controllers/graph_flow_controller.dart`)

`GraphFlowController` (extends `ChangeNotifier`) manages all animations:

- **Label flow**: When `DataExitedEvent` is emitted, `flowLabel()` gets a controller from a pre-allocated pool of 10 `AnimationController`s, animates the label along the edge's bezier curve, then emits `DataEnteredEvent` at the target node.
- **Glow**: Repeating pulse animation on active nodes.
- **Squish**: Short scale animation on node activation/tap.
- **Disable-after-processing**: After a label arrives, optionally disables the source node and/or traversed edge.

### 7. Rendering

Three stacked layers inside `ControlFlowScreen._buildGraphContainer()`:

```
Stack
  [1] EdgesWidget              CustomPainter: cubic bezier curves, arrowheads, static labels
  [2] AnimatedEdgeLabelWidgets Positioned widgets traveling along curves (one per active label)
  [3] GraphNodeRegions         Positioned at logical coords scaled to screen, 100x100 each
  [4] FloatingTextProperties   Animated offset + opacity fade above nodes
  [5] OverlayWidget            Optional modal (login, auth grant)
```

**Node positioning**: Nodes store logical positions in [0,1] normalized space. `_calculateNodePositions()` maps these to screen pixels via `LayoutBuilder` constraints. Nodes are draggable at runtime.

**Edge rendering**: `EdgesPainter` draws cubic bezier curves. Control points are offset horizontally from node centers by a fixed amount, with `curveBend` adding vertical offset to create the curve shape. Each edge has its own random seed for the optional hand-drawn jitter effect.

**Label animation**: `AnimatedEdgeLabelWidget` evaluates the bezier curve at parameter `t` (0.0 to 1.0) from the `AnimationController` to position the label. The label rotates to follow the curve tangent.

### 8. Screen (`sceens/control_flow_screen.dart`)

`ControlFlowScreen` is a `StatefulWidget` with `TickerProviderStateMixin`. It:

1. Creates `GraphFlowController` and `GraphRouter`
2. Loads a graph via `loadGraph(KnownGraph)` which returns an `FnGraphLoad` function
3. Subscribes to `GraphEventBus` for data flow, state change, and overlay events
4. Wraps the graph container in `ListenableBuilder(listenable: graph)` for dynamic node/edge reactivity
5. Provides a control panel with: graph selector dropdown, auto-repeat toggle, reset button, processing/travel duration sliders, disable-after-processing toggle

### 9. Configuration (`models/config/config.dart`)

Settings cascade via `InheritedWidget`:

- **InheritedGraphConfigSettings**: `StepSettings` (processing duration, travel duration, timeout) and `ControlSettings` (UI toggles for app bar, controls, debug panel, graph switching)
- **InheritedPaperSettings**: Hand-drawn effect parameters (frame duration, jitter seeds)
- **InheritedAppTitle**: Dynamic title updates

### 10. Event Server (`server/event_server.dart`)

Shelf-based HTTP server on port 4242. Accepts flatbuffer-encoded `RunRequest` payloads at `POST /api/v1/events` and returns `ComponentResult` responses. Health check at `GET /api/v1/health`.

The server also exposes JSON endpoints for dynamic graph mutation. It holds a reference to the active `GraphMutationController`, set by `ControlFlowScreen._initializeGraph()` whenever a graph is loaded.

**Graph mutation endpoints:**

| Method | Route | Body | Response |
|--------|-------|------|----------|
| `POST` | `/api/v1/graph/nodes` | `{ title, id?, x?, y?, state? }` | `{ id, updated }` |
| `DELETE` | `/api/v1/graph/nodes/<nodeId>` | — | `{ removed }` |
| `POST` | `/api/v1/graph/edges` | `{ fromNodeId, toNodeId, id?, label?, curveBend? }` | `{ id }` |
| `DELETE` | `/api/v1/graph/edges/<edgeId>` | — | `{ removed }` |
| `POST` | `/api/v1/graph/traverse` | `{ fromNodeId, toNodeId, edgeId?, label?, data? }` | `{ ok }` |
| `GET` | `/api/v1/graph` | — | `{ nodes, edges, startingNodeId }` |

Error responses: 409 if no graph is active, 404 if referenced node/edge doesn't exist, 400 for invalid JSON or missing required fields.

The node endpoint is an upsert: if a node with the given `id` already exists, its position and state are updated. The `state` field accepts: `unselected` (default), `selected`, `inProgress`, `error`, `disabled`.

The traverse endpoint sends a data packet from one node to another, triggering the full animation and processing pipeline. If `edgeId` is provided, traversal uses that specific edge; otherwise the router finds the first enabled edge between the two nodes.

### 11. Dynamic Routing (`models/graph/dynamic_routing.dart`)

Dynamic nodes cannot have hand-written processor logic, so they use a `DynamicRoutingStrategy` enum with a factory function `makeDynamicProcessor()` that generates a processor closure:

| Strategy | Behavior |
|----------|----------|
| `forward` | Route along the first enabled outgoing edge. Terminal if none. |
| `random` | Pick a random enabled outgoing edge via `router.randomOutgoingEdge()`. |
| `broadcast` | Send data to ALL enabled outgoing edges simultaneously. Calls `router.executeRoute()` for each edge except the last, which is returned as the processor's own decision. |
| `directed` | Route to a specific edge (by `directedTargetEdgeId`) or node (by `directedTargetNodeId`). Falls back to terminal if the target doesn't exist or is disabled. |

### 12. Mutation Controller (`controllers/graph_mutation_controller.dart`)

`GraphMutationController` wraps `ControlFlowGraph` mutation methods with ID generation, auto-positioning, and dynamic processor wiring. It is the single entry point for runtime graph mutation, used by both the UI buttons and the HTTP endpoints.

- `upsertDynamicNode()` — creates or updates a node. On create: builds a `RoutedGraphNodeData<String, String>` with a strategy-based processor. Auto-generates IDs (`dyn_node_N`) and positions (golden-angle spiral around center) if not provided. On update (ID exists): sets position and state. Accepts a `NodeState` parameter (`unselected`, `selected`, `inProgress`, `error`, `disabled`).
- `addDynamicEdge()` — creates a `GraphEdgeData` with auto-generated ID (`dyn_N_from_to_to`).
- `removeNode()` / `removeEdge()` — delegate to graph with cascading edge cleanup.

## Data Flow

The complete lifecycle of a data packet:

1. **Trigger**: User taps a node, or auto-repeat fires `_triggerStartingNode()`
2. **Process**: `RoutedGraphNodeData.process()` is called with a `DataPacket`
3. **Intercept**: Interceptors matching the incoming edge fire in order, executing side effects
4. **Route**: Processor returns a `RouteDecision`; `GraphRouter.executeRoute()` emits `DataExitedEvent`
5. **Animate**: `GraphFlowController.flowLabel()` picks a pooled `AnimationController`, creates an `AnimatedLabel`, animates it along the edge's bezier curve
6. **Arrive**: On animation complete, `DataEnteredEvent` is emitted for the target node
7. **Repeat**: Target node's `process()` is called with the packet; cycle continues
8. **Terminal**: A `RouteDecision.terminal()` ends the chain; if auto-repeat is on and the graph has an end, it resets and restarts after a delay

## Known Graphs

| Graph | Nodes | Edges | Key Pattern |
|-------|-------|-------|-------------|
| **Racers** | 5 | 6 | Random walk. Shared `racerProcessor()` picks a random outgoing edge. Endless loop (`hasEnd: false`). |
| **OAuth User Perspective** | 3 | 7 | Sequential flow with interceptors. Login and permission overlays extracted to `ProcessInterceptor` hooks. |
| **OAuth Access Token** | 3 | 4 | Conditional routing. Application routes to auth server or API server based on incoming edge. |
| **ACR** | 9 | 16 | Conditional dispatch + worker pools. Hypervisor routes to EchoTest or LEDSwitch pool. Pools load-balance across workers. Workers share a factory processor. |
| **New Graph** | 1 | 0 | Blank canvas with UUID identifier. Start node uses forward routing. Nodes and edges added dynamically via UI or HTTP API. |

## Adding a New Graph

1. Create `lib/models/knowngraphs/my_graph.dart`
2. Define a function matching `FnGraphLoad`:
   ```dart
   ControlFlowGraph myGraph(GraphRouter router, FnNodeStateCallback onUpdateNodeState,
       FnContextFetcher fnGetBuildContext, VoidCallback onEnd) {
     final builder = GraphBuilder()
       ..startAt('start')
       ..properties(isAutomatic: true, hasEnd: true)
       ..edge('start', 'end', label: 'go')
       ..node<String, String>('start', position: Offset(0.2, 0.5), title: "Start",
         processor: (d, r) async => RouteDecision.toNode(toNodeId: 'end', label: "going"))
       ..node<String, String>('end', position: Offset(0.8, 0.5), title: "End",
         processor: (d, r) async {
           onEnd();
           return RouteDecision.terminal();
         });
     return builder.build(router: router, onUpdateNodeState: onUpdateNodeState);
   }
   ```
3. Add an entry to `KnownGraph` enum in `known.dart`
4. Add the case to `loadGraph()` switch

## Dynamic Graph Mutation

Graphs can be mutated at runtime via three interfaces:

### 1. Low-level API (direct graph mutation)

```dart
graph.addNode(RoutedGraphNodeData(...));
graph.addEdge(GraphEdgeData(...));
graph.removeNode('nodeId');  // also removes connected edges
graph.removeEdge('edgeId');
```

All mutations call `notifyListeners()`, which triggers `ListenableBuilder` in the screen to rebuild the graph container with updated nodes and edges.

### 2. GraphMutationController (high-level API)

Handles ID generation, auto-positioning, and routing strategy selection:

```dart
controller.addDynamicNode(title: 'Hub', strategy: DynamicRoutingStrategy.broadcast);
controller.addDynamicEdge(fromNodeId: 'start', toNodeId: 'dyn_node_0');
```

### 3. HTTP API

JSON endpoints on port 4242. See Section 10 (Event Server) for the full endpoint reference.

```bash
curl -X POST http://localhost:4242/api/v1/graph/nodes -d '{"title":"Node A"}'
curl -X POST http://localhost:4242/api/v1/graph/edges -d '{"fromNodeId":"start","toNodeId":"dyn_node_0"}'
curl http://localhost:4242/api/v1/graph
```
