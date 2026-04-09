# STTextView — Custom NSView Component Patterns

**Repo:** `https://github.com/krzyzanowskim/STTextView.git`
**License:** BSD-style
**Language:** Swift (100%)
**Platforms:** macOS 12+, iOS 16+
**Stars:** ~1,300
**Author:** Marcin Krzyzanowski

## What This Repo Is

STTextView is a from-scratch NSTextView/UITextView replacement built on TextKit 2. It exists because NSTextView has deep legacy issues with TextKit 2 adoption (the author filed 20+ Apple Feedback reports documenting bugs). The codebase is the best example of building a production-quality custom NSView subclass — proper initialization, layout, drawing, event handling, plugin architecture, and cross-platform support.

Even if you're not building a text editor, **study this repo for its NSView patterns**. The same architecture applies to any embeddable custom view component.

## Source Map — Read These First

```
STTextView/
├── Sources/
│   ├── STTextViewCommon/              ← Shared code (platform-agnostic)
│   │   ├── STPlugin.swift             ← Plugin protocol definition
│   │   ├── STPluginContext.swift       ← Plugin context (access to text storage, layout)
│   │   └── STPluginEvents.swift        ← Event hooks for plugins
│   │
│   ├── STTextViewAppKit/              ← macOS NSView implementation
│   │   ├── STTextView.swift           ← THE main NSView subclass. Start here.
│   │   ├── STTextView+Gutter.swift    ← Line number gutter integration
│   │   ├── STTextView+NSTextLayoutManagerDelegate.swift
│   │   ├── STTextView+Mouse.swift     ← Mouse event handling
│   │   ├── STTextView+Keyboard.swift  ← Key event handling
│   │   ├── STTextView+Scrolling.swift ← Scroll handling
│   │   ├── STTextView+DragDrop.swift  ← Drag and drop support
│   │   │
│   │   ├── Gutter/
│   │   │   ├── STGutterView.swift     ← NSRulerView subclass for line numbers
│   │   │   ├── STGutterLineNumberCell.swift
│   │   │   └── STGutterMarker.swift   ← Breakpoint-style markers
│   │   │
│   │   ├── Overlays/
│   │   │   ├── STContentView.swift    ← Content container view
│   │   │   └── STLineHighlightView.swift ← Current line highlight
│   │   │
│   │   └── Plugin/
│   │       ├── Plugin.swift           ← Plugin protocol (AppKit-specific)
│   │       ├── STPlugin.swift
│   │       ├── STPluginContext.swift
│   │       └── STPluginEvents.swift
│   │
│   ├── STTextViewUIKit/               ← iOS UIView implementation (parallel structure)
│   │   ├── STTextView.swift           ← UIView subclass (same API surface)
│   │   └── ...
│   │
│   ├── STTextViewSwiftUI/             ← SwiftUI wrappers
│   │   └── TextViewUI.swift           ← NSViewRepresentable / UIViewRepresentable
│   │
│   └── STObjCLandShim/                ← Objective-C bridging for runtime tricks
│
├── TextEdit/                          ← Demo app (AppKit)
├── TextEdit.SwiftUI/                  ← Demo app (SwiftUI)
└── Package.swift
```

## Key Architectural Patterns

### Pattern 1: Proper NSView Subclass Lifecycle

STTextView demonstrates the full NSView lifecycle correctly:

```swift
class STTextView: NSView {
    // Required initializers
    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Set up layers, subviews, gesture recognizers
        wantsLayer = true
        // Set up TextKit 2 stack
        setupTextLayoutManager()
        setupTextContentStorage()
        // Set up gutter
        setupGutterView()
    }

    // Layout
    override func layout() {
        super.layout()
        updateContentViewFrame()
        updateGutterFrame()
    }

    // Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawBackground(in: dirtyRect)
        drawLineHighlight(in: dirtyRect)
    }

    // First responder
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { /* ... */ }
    override func resignFirstResponder() -> Bool { /* ... */ }
}
```

### Pattern 2: Plugin Architecture

STTextView uses a protocol-based plugin system that lets you extend behavior without subclassing:

```swift
protocol STPlugin {
    func setUp(context: STPluginContext)
    func tearDown()

    // Event hooks
    func willChangeText(in range: NSRange, replacementString: String?) -> Bool
    func didChangeText(in range: NSRange)
    func didChangeSelection(_ selection: [NSTextRange])
}

// Usage
let textView = STTextView()
textView.addPlugin(LineNumberPlugin())
textView.addPlugin(AutocompletionPlugin())
textView.addPlugin(BracketMatchingPlugin())
```

This is the pattern for any embeddable view that needs extensibility. **Prefer plugins over subclassing** for view customization.

### Pattern 3: Cross-Platform Architecture

The repo splits into platform-specific implementations sharing a common API:

```
STTextViewCommon/  ← Protocols, data types, shared logic
STTextViewAppKit/  ← NSView implementation
STTextViewUIKit/   ← UIView implementation
STTextViewSwiftUI/ ← Wrappers for both platforms
```

The key file to study is `Package.swift` — it shows how to structure SPM targets with platform conditionals:

```swift
.target(
    name: "STTextViewAppKit",
    dependencies: ["STTextViewCommon"],
    condition: .when(platforms: [.macOS])
),
.target(
    name: "STTextViewUIKit",
    dependencies: ["STTextViewCommon"],
    condition: .when(platforms: [.iOS, .macCatalyst, .visionOS])
),
```

### Pattern 4: Gutter/Ruler View (NSRulerView)

The line number gutter is implemented as an NSRulerView attached to the scroll view:

```swift
// Conceptual — study STGutterView.swift for real implementation
let scrollView = NSScrollView()
let gutterView = STGutterView(scrollView: scrollView, orientation: .verticalRuler)
scrollView.verticalRulerView = gutterView
scrollView.hasVerticalRuler = true
scrollView.rulersVisible = true
```

This is the AppKit-native way to add sidebars to scrolling content. The gutter syncs with scroll position automatically via NSRulerView infrastructure.

### Pattern 5: Wrapping for SwiftUI Consumption

STTextView provides SwiftUI wrappers in `STTextViewSwiftUI/`:

```swift
// Simplified — study TextViewUI.swift for real implementation
struct TextViewUI: NSViewRepresentable {
    @Binding var text: String
    var plugins: [STPlugin]

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()
        let textView = scrollView.documentView as! STTextView
        plugins.forEach { textView.addPlugin($0) }
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Sync text binding → text view
    }

    class Coordinator: NSObject, STTextViewDelegate {
        // Sync text view changes → binding
    }
}
```

## Adapting for Your Use Case

### Building any embeddable AppKit component:
1. Study `STTextView.swift` for proper NSView subclass structure
2. Study the Plugin protocol for extensibility patterns
3. Study the SwiftUI wrapper for NSViewRepresentable best practices

### Building a view with a side gutter/ruler:
1. Study `Gutter/STGutterView.swift` for NSRulerView patterns
2. Study how it syncs with NSScrollView

### Building a cross-platform component (macOS + iOS):
1. Study the `STTextViewCommon` → `STTextViewAppKit` / `STTextViewUIKit` split
2. Study `Package.swift` for platform-conditional SPM targets
