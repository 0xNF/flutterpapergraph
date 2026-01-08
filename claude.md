# Flutter Control Flow Animation System - Design Discussion

## 2. **Widget Composition Approach**
**Pros:**
- Leverages Flutter's widget ecosystem
- Easier state management with standard patterns
- Simpler click handling with built-in gesture detection

**Implementation considerations:**
- Overlay approach: absolute positioning with `Positioned`
- Custom `LayoutDelegate` for precise control
- Multiple rendering layers (nodes layer, connections layer, animation layer)

---

## Connection Rendering Strategies

### **Cubic Bezier Splines**
Most suitable for control flow diagrams.

**Approaches:**
1. **Direct Path Calculation**
   - Calculate control points based on node positions
   - Generate cubic bezier curves manually
   - Draw using `canvas.drawPath()` with quadratic/cubic bezier operations

2. **Cardinal/Catmull-Rom Splines**
   - Smoother curves through connection points
   - More complex but visually superior
   - Better for cyclical flows that need to avoid overlaps

3. **Straight Lines with Curves**
   - Straight segments with curved junction points
   - Common in flowchart tools (Lucidchart, Draw.io style)
   - Easier to compute and still aesthetic

### **Control Point Strategies**
- **Fixed offset**: Points at fixed distance from nodes
- **Dynamic routing**: Avoid other nodes/connections
- **Bidirectional adjustment**: Different curves for in/out connections
- **Tension parameters**: Adjustable curve smoothness

---

## Node State & Interaction Model

### **Click Detection**
- **Canvas approach**: Implement custom hit detection using bounding box math
- **Widget approach**: Wrap nodes in `GestureDetector`
- Consider: node radius/shape (circle vs rectangle) affects hit detection complexity

### **Animation Triggers**
Think about what flows to animate:
1. **Along edges** (particles/flows traveling the spline)
2. **Node highlighting** (visual feedback for activation)
3. **Transition effects** (node state changes)
4. **Sequential activation** (automatic flow propagation)

### **State Architecture**
```
Graph Model Layer
├─ Nodes (id, position, metadata)
├─ Edges (from, to, metadata)
└─ Animation State (active nodes, flowing edges, timestamps)

Controller Layer
└─ Manages transitions, triggers animations

Renderer Layer
└─ Canvas or Widget tree visualization
```

---

## Scaling Strategy (Non-Reflow Preservation)

### **Aspect Ratio Preservation**
1. **Transform-based scaling**
   - Store canvas scale factor
   - Apply via `canvas.scale()` or transform matrix
   - No widget reflow needed
   - Natural and performant

2. **Layout constraints**
   - Fix container size
   - Scale content via `Transform.scale()` if widget-based
   - Less elegant but works

3. **Responsive coordinate system**
   - Maintain virtual/logical coordinates
   - Map to screen space at render time
   - Most flexible approach

### **Implementation Options**
- Use `MediaQuery` to detect size changes
- Debounce resize events to prevent jank
- Pre-calculate all positions in normalized space
- Apply single scale transformation at render time

---

## Animation Implementation Approaches

### **1. Ticker-Based (Most Control)**
- `Ticker` + custom animation logic
- Frame-by-frame state updates
- Best for complex, multi-layered animations
- Requires careful performance management

### **2. AnimationController + Tween**
- Standard Flutter pattern
- Good for discrete animations (node activation)
- Can chain multiple controllers
- Less flexible for emergent animations (flowing particles)

### **3. Hybrid Approach**
- AnimationControllers for coordinated timing
- Ticker for continuous effects (flowing animations)
- State machine for flow logic

### **Flow Animation Concepts**
- **Particles/Flowing Lines**: Animated offset along spline curves
- **Pulse Effects**: Expanding circles from nodes
- **Sequential Activation**: Delayed animations along paths
- **Connection Highlighting**: Opacity/color changes
- **Progress Indicators**: Filled paths showing completion

---

## Performance Considerations

### **For Canvas Approach**
- Only redraw when state actually changes (not every frame if possible)
- Use `RepaintBoundary` for static portions
- Cache expensive calculations (spline generation)
- Consider `PictureRecorder` for static node definitions

### **For Widget Approach**
- Use `const` constructors aggressively
- `RepaintBoundary` around non-animating elements
- Consider `SliverMultiBoxAdaptorWidget` for large graphs
- Careful with opacity animations (expensive in Flutter)

### **General**
- Profile with `DevTools`
- Test with many nodes (100+) to find bottlenecks
- Consider off-screen rendering for preview generation

---

## Recommended Hybrid Architecture

1. **Canvas for graph rendering** (nodes + connections + animations)
2. **Custom gesture detection** for click handling
3. **AnimationController** for timing orchestration
4. **State management** (Provider/Riverpod) for graph model
5. **Ticker** for optional real-time flowing effects
6. **Transform-based scaling** for size responsiveness

---

## Key Implemenation Nodes

1. Between 2-20 nodes at a time
2. How complex are the spline curves: There are bends and arrowheads.
3. Do connections need labels: Sometimes
4. Is drag-to-create connections needed: Absolutely not.


# Flutter Widget-Based Control Flow Animation - Refined Design


## Architecture Overview

### **Layer Structure**
```
GraphContainer (stateful, manages overall state)
├─ ConnectionsLayer (Positioned, renders all splines + animated labels)
├─ NodesLayer (Positioned stack of individual nodes)
└─ AnimationController (orchestrates all timing)
```

**Key insight**: Separate connections from nodes. Connections are "background," nodes are interactive foreground.

---

## Node Implementation

### **Node Widget Structure**
```
GestureDetector (click detection)
└─ AnimatedBuilder (reacts to animation changes)
    └─ Container/CustomPaint (visual representation)
        ├─ Glowing border (AnimatedBuilder tracking glow intensity)
        ├─ Content (static)
        └─ Squish effect (Transform.scale with animation)
```

### **Animations per Node**
1. **Glow effect**
   - `AnimationController` with repeating/pulsing behavior
   - Update border shadow or use `BoxShadow` with glow color
   - Or: `Container` with `decoration` that animates via `AnimatedBuilder`

2. **Squish on activation**
   - Scale animation (0.95 to 1.0 range)
   - Short duration (200ms)
   - Used when node becomes "active" in flow

3. **State indicators**
   - Color/opacity changes for inactive/active/complete states
   - Smooth transitions between states

### **Node Position Strategy**
- Store logical positions (0.0 to 1.0 normalized coordinates)
- Convert to screen space in `GraphContainer`
- Use `Positioned` with calculated offsets
- Nodes remain at fixed logical positions regardless of screen size

---

## Connection Layer Implementation

### **Rendering Approach**

**Single `CustomPaint` widget covering entire graph area:**
- Render all splines in one paint call
- More efficient than individual connection widgets
- Easier to manage z-ordering (connections always under nodes)

### **Spline Calculation**

**Cubic Bezier with automatic control points:**
```
Node A → Control Point 1 → Control Point 2 → Node B
```

**Control point strategy:**
- Use fixed offset approach: control points at distance `d` horizontally from node
- Direction: outgoing nodes move right, incoming move left
- Handles multiple connections gracefully
- Clean, predictable curves

**Alternative consideration:**
- If connections need to avoid other nodes, implement simple collision avoidance
- For 2-10 nodes, usually not necessary
- Directional flow typically prevents overlap anyway

### **CustomPaint Implementation**
```
class ConnectionsPainter extends CustomPainter {
  // Input: list of connections with node positions
  // Output: draws all splines and animated labels
  
  // For each connection:
  // - Create Path using quadraticBezierTo or cubicBezierTo
  // - Draw with stroke (perhaps dashed or solid)
  // - Calculate label position via path evaluation
}
```

**Path evaluation for label positioning:**
- At animation progress `t` (0.0 to 1.0), interpolate position along curve
- Store pre-calculated bezier coefficients for performance
- Move text widget to that position

---

## Animated Labels on Connections

### **Implementation Pattern**

**Separate animated label widgets:**
```
GraphContainer
├─ ConnectionsPainter (static paths)
├─ AnimatedConnectionLabels (floating text, repositioning)
│  └─ Multiple Label widgets (one per active animation)
└─ NodesLayer
```

**Label animation mechanics:**
1. **Trigger condition**: Label activation (time-based or event-based)
2. **Animation state**:
   - `t` progresses from 0.0 to 1.0 over duration
   - Position calculated via bezier evaluation at `t`
   - Opacity fade in/out at extremes
3. **Position calculation**:
   - Use same bezier curve math as the connection spline
   - Evaluate `de Casteljau's algorithm` or cubic bezier formula at progress `t`
   - Slight offset perpendicular to curve for readability

**Code structure:**
```
class AnimatedConnectionLabel extends StatefulWidget {
  final Offset startNodePos;
  final Offset endNodePos;
  final String label;
  final Duration duration;
  // animation callback or ticker-based
}
```

---

## State Management Architecture

### **Graph Model**
```dart
class GraphNode {
  final String id;
  final Offset logicalPosition; // normalized 0-1
  final String label;
  final VoidCallback onTap;
  // animation state
  bool isActive;
  bool isGlowing;
}

class GraphConnection {
  final String fromId;
  final String toId;
  // metadata
}

class ControlFlowGraph {
  final List<GraphNode> nodes;
  final List<GraphConnection> connections;
  // methods to query, activate, animate
}
```

### **Animation State Management**
```dart
class GraphAnimationController {
  // Controls all animations centrally
  
  AnimationController _glowController;
  AnimationController _squishController;
  AnimationController _labelFlowController;
  
  // Methods:
  // - activateNode(nodeId)
  // - flowLabel(connectionId)
  // - resetAll()
}
```

**State container options:**
- Simple `Provider<GraphAnimationController>` singleton
- Or extend `GraphAnimationController` with `ChangeNotifier`
- Or use `ValueNotifier` for individual node states

---

## Scaling & Layout

### **Container Setup**
```dart
AspectRatio(
  aspectRatio: 16 / 9, // or whatever your graph layout is
  child: Container(
    color: Colors.background,
    child: Stack(
      children: [
        // ConnectionsPainter takes full size
        CustomPaint(
          painter: ConnectionsPainter(...),
          size: Size.infinite,
        ),
        // Nodes positioned absolutely
        for (var node in nodes)
          Positioned(
            left: node.logicalPosition.dx * containerWidth,
            top: node.logicalPosition.dy * containerHeight,
            child: NodeWidget(node),
          ),
      ],
    ),
  ),
)
```

**Benefit**: No reflow, just scale. AspectRatio locks proportions, nodes scale naturally via `Positioned` calculation.

---

## Animation Techniques by Effect

### **1. Glowing Border**
**Option A: Animated shadow**
```dart
AnimatedBuilder(
  animation: glowController,
  builder: (context, child) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(glowAnimation.value),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  },
)
```

**Option B: Custom paint for glow**
- More control over appearance
- Slightly more complex

**Orchestration:**
- Pulse animation: repeat in range [0.3, 1.0] opacity
- Only when node is "active"
- Smooth easing curves (e.g., `Curves.easeInOut`)

### **2. Squish Effect**
```dart
Transform.scale(
  scale: 1.0 - (squishAnimation.value * 0.05), // 5% squish
  child: nodeChild,
)
```
- Trigger on node activation
- Short duration (150-250ms)
- Single play, not repeating
- Coordinated with glow start for visual feedback

### **3. Text Along Spline**
**Critical math**: Bezier curve parametric evaluation

```dart
// Cubic bezier evaluation
Offset evaluateCubicBezier(
  Offset p0, Offset p1, Offset p2, Offset p3, double t
) {
  final mt = 1 - t;
  final mt2 = mt * mt;
  final t2 = t * t;
  
  return Offset(
    mt2 * mt * p0.dx + 3 * mt2 * t * p1.dx + 3 * mt * t2 * p2.dx + t2 * t * p3.dx,
    mt2 * mt * p0.dy + 3 * mt2 * t * p1.dy + 3 * mt * t2 * p2.dy + t2 * t * p3.dy,
  );
}
```

**Rotation along curve (optional but nice):**
```dart
// Tangent at parameter t
Offset tangent = evaluateCubicBezierDerivative(..., t);
double angle = atan2(tangent.dy, tangent.dx);
```

---

## Gesture Handling

### **Node Click Detection**
```dart
GestureDetector(
  onTap: () => onNodeTapped(nodeId),
  child: AnimatedBuilder(...),
)
```

**Optional refinement for non-rectangular nodes:**
- Use `GestureDetector` with custom `RawGestureDetector` if circular
- Or add padding to gesture bounds
- For 2-10 nodes, simple rectangular tap target is fine

---

## Animation Orchestration Pattern

### **Central Controller Pattern**
```dart
class GraphFlowController extends ChangeNotifier {
  // State
  Map<String, bool> nodeActive = {};
  
  // Animation controllers
  late AnimationController glowAnim;
  late AnimationController squishAnim;
  late AnimationController labelFlowAnim;
  
  // Public methods
  void activateNode(String nodeId) {
    nodeActive[nodeId] = true;
    squishAnim.forward();
    glowAnim.repeat(reverse: true);
    notifyListeners();
  }
  
  void flowLabel(String connectionId, Duration duration) {
    labelFlowAnim.duration = duration;
    labelFlowAnim.forward(from: 0.0);
  }
}
```

**Usage:**
```dart
context.read<GraphFlowController>().activateNode('node1');
```

---

## Performance Optimizations (Likely Unnecessary but Worth Considering)

1. **Throttle repaints**: Only rebuild `CustomPaint` when connections actually change
2. **Memoize bezier calculations**: Cache control points, evaluate during paint
3. **RepaintBoundary** around static node content
4. **Const constructors** throughout
5. **Limit animation framerate** if battery life matters (unlikely here, but possible)

For 2-10 nodes on modern devices, you likely won't need these.

---

## Recommended Tech Stack

- **State**: `Provider` + `ChangeNotifier` (simple, proven)
- **Animation**: `AnimationController` + `AnimatedBuilder` (standard Flutter)
- **Layout**: `Stack` + `Positioned` (no reflow, clean)
- **Rendering**: Single `CustomPaint` for connections (efficient, simple)
- **Gestures**: Standard `GestureDetector` (no custom hit detection needed)

---

## Implementation Sequence

1. **Static structure**: Layout nodes in `Stack` with calculated positions
2. **Connection rendering**: Build `ConnectionsPainter` to draw splines
3. **Glow animation**: Add `AnimationController` to pulse border
4. **Squish effect**: Add node tap detection and transform animation
5. **Label flow**: Implement animated label positioning along curves
6. **Polish**: Easing curves, timing tweaks, visual refinement

This is a straightforward widget composition task with standard Flutter animation patterns. No custom rendering, no performance headaches, just clean reactive UI.