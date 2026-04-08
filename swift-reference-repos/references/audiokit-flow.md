# AudioKit/Flow — SwiftUI Node Graph Editor

**Repo:** `https://github.com/AudioKit/Flow.git`
**License:** MIT
**Language:** Swift (100%)
**Platforms:** iOS, macOS, visionOS, watchOS, tvOS, Linux, Wasm, Android
**Dependencies:** None (zero package dependencies)
**SPM:** `.package(url: "https://github.com/AudioKit/Flow.git", from: "1.0.4")`

## What This Repo Is

Flow is a generic SwiftUI node graph editor built by Taylor Holliday (creator of Audulus) and Aurelius Prochazka (founder of AudioKit). It renders draggable nodes with typed input/output ports and bezier wire connections between them. Originally designed for audio signal flow, it's generic enough for any directed graph UI: data pipelines, workflow builders, state machines, shader graphs, etc.

## Source Map — Read These First

```
Flow/
├── Sources/Flow/
│   ├── Model/
│   │   ├── Patch.swift          ← THE data model. Contains nodes + wires. Start here.
│   │   ├── Node.swift           ← Individual node: name, position, inputs, outputs
│   │   ├── Wire.swift           ← Connection between an OutputID and InputID
│   │   ├── Port.swift           ← Input/output port definition with name and type
│   │   ├── InputID.swift        ← (nodeIndex, portIndex) identifier for input ports
│   │   └── OutputID.swift       ← (nodeIndex, portIndex) identifier for output ports
│   │
│   ├── Views/
│   │   ├── NodeEditor.swift     ← THE top-level SwiftUI view. Renders the full graph.
│   │   ├── NodeView.swift       ← Renders a single node with its ports
│   │   ├── PatchView.swift      ← Renders wires between nodes
│   │   └── PortView.swift       ← Renders individual input/output ports
│   │
│   ├── Layout/
│   │   ├── Patch+Layout.swift   ← Recursive layout algorithm for auto-positioning
│   │   └── NodeLayout.swift     ← Size/position calculations for individual nodes
│   │
│   └── Gestures/
│       ├── DragInfo.swift       ← Drag state tracking
│       └── Patch+Gestures.swift ← Hit testing, node dragging, wire creation
│
├── Tests/FlowTests/
│   └── FlowTests.swift          ← Test cases for patch operations
│
├── Package.swift                ← SPM package definition
└── Demo/                        ← Example app (if present)
```

## Core Data Model

The entire graph is represented by three types:

### Patch (the graph)
```swift
struct Patch {
    var nodes: [Node]
    var wires: Set<Wire>
}
```

A `Patch` is the complete graph state. It owns an array of nodes and a set of wires. The key insight: nodes are identified by their **index** in the array, not by UUID. This makes the data model very simple but means node deletion requires re-indexing.

### Node (a vertex)
```swift
struct Node {
    var name: String
    var position: CGPoint
    var inputs: [Port]
    var outputs: [Port]
    var titleBarColor: Color  // Visual customization
}
```

### Wire (an edge)
```swift
struct Wire: Hashable {
    var from: OutputID  // (nodeIndex: Int, portIndex: Int)
    var to: InputID     // (nodeIndex: Int, portIndex: Int)
}
```

Wires are directional: always from an output port to an input port. The `Hashable` conformance lets them live in a `Set`, preventing duplicate connections.

## Key Architectural Patterns

### Pattern 1: Graph as Value Type
The entire `Patch` is a Swift struct (value type). This means:
- The graph is trivially copyable (undo/redo = save previous patch)
- SwiftUI's `@State`/`@Binding` works naturally
- No reference cycles, no retain issues

### Pattern 2: Index-Based Identity
Nodes are identified by array index, not UUID. Ports are identified by `(nodeIndex, portIndex)` pairs. This is simpler than entity-component systems but has a tradeoff: deleting a node invalidates wire references.

### Pattern 3: Recursive Layout
`Patch.recursiveLayout(nodeIndex:at:)` positions nodes by walking the graph backwards from an output node. Each node positions its inputs recursively, spacing them vertically. This gives you auto-layout for free.

### Pattern 4: SwiftUI Canvas with Gesture Composition
The `NodeEditor` view uses SwiftUI's gesture system (not AppKit/UIKit gesture recognizers) for:
- Node dragging via `.gesture(DragGesture())`
- Wire creation via drag from output port to input port
- Selection via tap + shift-tap

### Pattern 5: Configurable via View Modifiers
```swift
NodeEditor(patch: $patch, selection: $selection)
    .onNodeMoved { index, location in }
    .onWireAdded { wire in }
    .onWireRemoved { wire in }
```

The `NodeEditor` exposes callbacks as SwiftUI-idiomatic view modifiers, not delegate protocols.

## Usage Example

```swift
import Flow

struct ContentView: View {
    @State var patch = Patch(
        nodes: [
            Node(name: "Input", outputs: ["signal"]),
            Node(name: "Filter", inputs: ["in"], outputs: ["out"]),
            Node(name: "Output", inputs: ["audio"])
        ],
        wires: Set([
            Wire(from: OutputID(0, 0), to: InputID(1, 0)),
            Wire(from: OutputID(1, 0), to: InputID(2, 0))
        ])
    )
    @State var selection = Set<NodeIndex>()

    var body: some View {
        NodeEditor(patch: $patch, selection: $selection)
    }
}
```

## Adapting for Your Use Case

Flow is intentionally minimal. To build a production flow editor, you'll likely need to add:

1. **Custom node content** — Flow nodes show only name + ports. Overlay your own SwiftUI views inside nodes for controls, previews, parameters.
2. **Port type checking** — Flow doesn't enforce type compatibility between ports. Add validation in the `onWireAdded` callback.
3. **Persistence** — `Patch` is `Codable`-ready since it's composed of simple value types. Add `Codable` conformance for save/load.
4. **Zoom/pan** — Flow renders at fixed scale. Wrap in a `ScrollView` with `MagnificationGesture` or build your own camera transform (see the infinite-canvas patterns in the `macos-native-canvas` skill).
5. **Execution engine** — Flow is purely visual. To actually *run* the graph, you need a topological sort + execution engine that walks the graph and evaluates each node.
