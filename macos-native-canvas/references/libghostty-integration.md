# libghostty Integration Guide

## What libghostty provides

libghostty is a family of libraries extracted from Ghostty's core:

- **libghostty-vt** (available now): Zero-dependency VT sequence parser + terminal state manager. Handles cursor position, styles, text wrapping, scrollback, reflow. SIMD-optimized parsing. No renderer — you provide your own.
- **libghostty (full, future)**: Adds Metal/OpenGL rendering, font handling, PTY management, input encoding. "Provide us with a Metal surface and we'll handle the rest."

## Current status (as of early 2026)

- **libghostty-vt C API**: Available, usable, but API signatures still in flux. Not yet version-tagged.
- **libghostty-spm**: Community-maintained Swift Package wrapping prebuilt `GhosttyKit.xcframework`.
- **Ghostty macOS app**: Production reference implementation of Swift + AppKit consuming libghostty C API.
- **Ghostling**: Minimal complete terminal emulator in a single C file using libghostty + Raylib.

## Architecture Pattern

```
┌─────────────────────────────────────────┐
│  Your Swift App (AppKit + SwiftUI)       │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  NSView subclass                  │   │
│  │  - owns CAMetalLayer              │   │
│  │  - forwards input events          │   │
│  │  - manages surface lifecycle      │   │
│  └──────────┬───────────────────────┘   │
│             │ C API calls                │
│  ┌──────────▼───────────────────────┐   │
│  │  libghostty (static library)      │   │
│  │  - VT parsing + state            │   │
│  │  - Metal rendering (cell passes)  │   │
│  │  - PTY management                │   │
│  │  - Font rasterization + atlas     │   │
│  │  - Shell integration             │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### What the host app owns vs what libghostty owns

**libghostty owns:**
- Terminal emulation (VT sequence parsing, terminal state)
- Metal rendering (multi-pass cell rendering pipeline)
- PTY creation and management
- Font rasterization to texture atlas
- Shell integration scripts (bash, zsh, fish)
- Keyboard input encoding

**Host app owns:**
- Window and view lifecycle (NSWindow, NSView)
- Providing the NSView/CAMetalLayer surface
- Input event forwarding (NSEvent → libghostty)
- Layout and positioning of terminal surfaces
- Tabs, splits, and multi-window management
- Application-level features (search, settings, etc.)

## Surface Lifecycle

A "surface" is a single terminal instance. Key lifecycle:

```
1. Create surface (ghostty_surface_new or equivalent)
   - Provides NSView to libghostty
   - libghostty creates CAMetalLayer, PTY, IO thread, render thread
2. Forward events
   - Keyboard: NSEvent → ghostty_surface_key()
   - Mouse: NSEvent → ghostty_surface_mouse()
   - Resize: layout change → ghostty_surface_resize()
3. Destroy surface
   - ghostty_surface_free()
   - Tears down threads, closes PTY
```

### Surface in NSView

```swift
// Conceptual pattern — actual API depends on libghostty version
class TerminalSurfaceView: NSView {
    private var surface: OpaquePointer?  // ghostty_surface_t

    func createSurface(config: GhosttyConfig) {
        // libghostty creates the Metal layer and attaches to this view
        surface = ghostty_surface_new(config, Unmanaged.passUnretained(self).toOpaque())
    }

    override func keyDown(with event: NSEvent) {
        guard let surface = surface else { return }
        // Forward to libghostty for processing
        ghostty_surface_key_event(surface, /* key event data */)
    }

    override func layout() {
        super.layout()
        guard let surface = surface else { return }
        let size = convertToBacking(bounds).size
        ghostty_surface_set_size(surface, UInt32(size.width), UInt32(size.height))
    }

    // NSTextInputClient for CJK/emoji composition
    // Required for proper input method handling
}
```

## Threading Model

Each terminal surface runs three threads:

```
Main thread (shared):
  - AppKit event loop
  - Gesture handling
  - Layout
  - SwiftUI updates

Per-surface IO thread:
  - PTY read() in a loop
  - VT sequence parsing
  - Terminal state updates
  - Shell integration event handling

Per-surface Render thread:
  - Reads terminal state (with synchronization)
  - Updates GPU buffers (cell data, atlas)
  - Encodes Metal command buffer
  - Presents to CAMetalLayer
```

## Rendering Pipeline (Ghostty's approach)

Multi-pass, back-to-front, per frame:

### Pass 1: Backgrounds
Renders colored rectangles for cells with non-default background colors. Simple instanced quad rendering.

### Pass 2: Cell Text
The complex pass. For each visible cell:
- Look up glyph in texture atlas (rasterize if not cached)
- Pack cell data into CellText struct (32 bytes, GPU-optimized):
  - Grid position, glyph atlas coordinates
  - Foreground color, background color
  - Style flags (bold, italic, underline)
- Upload as instance buffer
- Draw instanced quads sampling from atlas texture

### Pass 3: Cursor
Renders cursor shape (block, underline, bar) at current position.

### Pass 4: Post-processing (optional)
User-provided custom shaders (MSL) for visual effects (CRT, blur, etc.).

### Swap Chain
Triple buffered on Metal (3 frame states). Semaphore prevents CPU from overwriting GPU-in-use buffers. When `nextFrame()` is called, waits on semaphore to acquire available frame state.

## Multi-Terminal Canvas Integration

For a canvas of terminals, each terminal tile would be:

```swift
class TerminalTile: CanvasObject {
    let id = UUID()
    var worldPosition: SIMD2<Float>
    var worldSize: SIMD2<Float> = SIMD2(800, 600)
    var zIndex: Int = 0

    private var surface: OpaquePointer?  // ghostty_surface_t
    private var surfaceView: TerminalSurfaceView?
    private var cachedTexture: MTLTexture?  // For thumbnail LOD

    func render(encoder: MTLRenderCommandEncoder, camera: Camera, lod: LODLevel) {
        switch lod {
        case .full:
            // libghostty renders directly to its own Metal layer
            // Position the NSView in screen space
            updateSurfaceViewFrame(camera: camera)
        case .thumbnail:
            // Render cached texture as a quad
            if cachedTexture == nil || isDirty {
                cachedTexture = captureCurrentFrame()
            }
            drawTexturedQuad(encoder: encoder, texture: cachedTexture!, camera: camera)
        case .placeholder:
            drawColoredRect(encoder: encoder, camera: camera)
        }
    }
}
```

## PTY Piping Between Terminals

A "pipe" from Terminal A → Terminal B means routing A's stdout to B's stdin:

```swift
class TerminalPipe {
    let source: TerminalTile
    let target: TerminalTile
    private var pipeThread: Thread?

    func activate() {
        pipeThread = Thread {
            // Read from source's PTY stdout
            // Write to target's PTY stdin
            // This runs in a dedicated thread
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }

            while !Thread.current.isCancelled {
                let bytesRead = read(self.source.ptyReadFd, buffer, 4096)
                if bytesRead > 0 {
                    write(self.target.ptyWriteFd, buffer, bytesRead)
                }
            }
        }
        pipeThread?.start()
    }

    func deactivate() {
        pipeThread?.cancel()
    }
}
```

## Key Files in Ghostty Source

Study these in `github.com/ghostty-org/ghostty`:

| File | Purpose |
|------|---------|
| `macos/Sources/App/` | Swift app entry point, AppDelegate |
| `macos/Sources/Ghostty/SurfaceView.swift` | NSView hosting terminal surface |
| `macos/Sources/Ghostty/Ghostty.Config.swift` | Swift wrapper around C config API |
| `src/Surface.zig` | Core surface abstraction |
| `src/renderer/Metal.zig` | Metal backend (swap chain, passes) |
| `src/renderer/metal/shaders.zig` | Shader definitions, CellText struct |
| `src/renderer/metal/cell.zig` | Cell rendering logic |
| `src/termio/Termio.zig` | Terminal IO thread |
| `src/terminal/Terminal.zig` | Terminal state machine |
| `src/apprt/embedded.zig` | Embedded library mode |
| `src/font/main.zig` | Font loading + atlas management |

Also study:
- `github.com/ghostty-org/ghostling` — minimal C example
- Kytos terminal (jwintz.gitlabpages.inria.fr) — full Swift + libghostty app (~1,500 LOC)
- awesome-libghostty list — community projects using libghostty
