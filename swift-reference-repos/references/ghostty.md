# Ghostty — Terminal Embedding & C Library Integration

**Repos:**
- `https://github.com/ghostty-org/ghostty.git` (full terminal)
- `https://github.com/ghostty-org/ghostling.git` (minimal libghostty demo)
**License:** MIT | **Stars:** ~30k+
**Creator:** Mitchell Hashimoto (HashiCorp founder)

## Why This Is Here

Ghostty is the reference for embedding a C library's view surface into a macOS AppKit app. The pattern — Swift app consuming a Zig-compiled C library via bridging headers, with the library owning rendering and state while the app owns windowing and events — is exactly what you'd use for embedding libghostty terminals, custom renderers, or any native C/Zig/Rust library into an AppKit view hierarchy.

**Also see:** `references/libghostty-integration.md` in the `macos-native-canvas` skill for deeper libghostty-specific integration patterns.

## Source Map — Desktop App Patterns

Focus on the macOS app layer for desktop architecture patterns:

```
ghostty/macos/Sources/
├── App.swift                          ← @main entry, scene lifecycle
├── AppDelegate.swift                  ← NSApplicationDelegate, window management
│
├── Ghostty/
│   ├── SurfaceView.swift              ← KEY: NSView hosting a terminal surface
│   ├── SurfaceView+Keyboard.swift     ← AppKit keyboard events → C library
│   ├── SurfaceView+Mouse.swift        ← AppKit mouse events → C library
│   ├── TerminalController.swift       ← NSWindowController managing terminal surfaces
│   ├── TerminalView.swift             ← SwiftUI wrapper for SurfaceView
│   └── Package.swift                  ← Swift types wrapping C API types
│
└── Helpers/                           ← Utilities, extensions
```

And Ghostling for the minimal pattern:

```
ghostling/
└── main.c                             ← ~600 lines. The entire terminal in C.
```

## Key Desktop App Patterns

### Pattern 1: NSView Hosting an External Render Surface

SurfaceView is an NSView subclass that hosts a CAMetalLayer. The C library (libghostty) owns the Metal rendering; the NSView just provides the surface:

```swift
class SurfaceView: NSView {
    private var metalLayer: CAMetalLayer!
    private var surface: ghostty_surface_t?  // C API handle

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        metalLayer = CAMetalLayer()
        metalLayer.contentsScale = window?.backingScaleFactor ?? 2.0
        layer = metalLayer

        // Create the C library surface, passing our metal layer
        surface = ghostty_surface_create(metalLayer)
    }

    override func layout() {
        super.layout()
        metalLayer.drawableSize = convertToBacking(bounds).size
        // Notify C library of resize
        ghostty_surface_set_size(surface, UInt32(bounds.width), UInt32(bounds.height))
    }
}
```

**This is the pattern for any embedded renderer** — Metal views, GPU-accelerated canvases, game engine views, etc.

### Pattern 2: AppKit Event Forwarding to C Library

The SurfaceView captures AppKit events and translates them into C library calls:

```swift
extension SurfaceView {
    override func keyDown(with event: NSEvent) {
        // Translate NSEvent → C library key event
        let key = ghostty_key_from_event(event)
        ghostty_surface_key_event(surface, key)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_event(surface, point.x, point.y, .press)
    }

    override func scrollWheel(with event: NSEvent) {
        ghostty_surface_scroll(surface, event.deltaX, event.deltaY)
    }

    override var acceptsFirstResponder: Bool { true }
}
```

### Pattern 3: Multi-Surface Window Management

Ghostty manages multiple terminal surfaces (tabs, splits) via NSWindowController:

```
TerminalController (NSWindowController)
├── Window
│   ├── NSSplitView (for split panes)
│   │   ├── SurfaceView (terminal 1)
│   │   └── SurfaceView (terminal 2)
│   └── Tab bar
│       ├── Tab 1 → SurfaceView
│       └── Tab 2 → SurfaceView
```

Each SurfaceView has its own surface handle from the C library, its own IO thread, and its own render thread. The window controller manages their lifecycle.

### Pattern 4: Threading Model

Per terminal surface:
```
Main Thread    → AppKit events, layout, view lifecycle
IO Thread      → PTY read/write, VT parsing, state updates
Render Thread  → Metal command buffer encoding, frame submission
```

Communication: lock-free ring buffers for data, semaphores for frame synchronization.

## Related libghostty Projects (Desktop Apps)

Study these for more examples of libghostty in macOS apps:

- **Kytos** — macOS terminal built on libghostty + KelyphosKit
- **OpenOwl** — macOS Git GUI with embedded terminal (Swift + libghostty + Metal)
- **Factory Floor** — macOS workspace with git worktrees + embedded Claude Code agents
- **Supacode** — macOS command center for parallel coding agents

See `awesome-libghostty` (`github.com/Uzaaft/awesome-libghostty`) for the full list.
