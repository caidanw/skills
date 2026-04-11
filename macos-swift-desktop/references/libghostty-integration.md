# libghostty Integration Guide

Embedding a terminal emulator inside a Swift macOS app via Ghostty's libghostty C library. This doc covers the specific patterns for libghostty; for the generic "embed a C library that owns a render surface" pattern, see `advanced-rendering.md`.

## What libghostty provides

libghostty is a family of libraries extracted from Ghostty's core:

- **libghostty-vt** — zero-dependency VT sequence parser and terminal state manager. Handles cursor position, styles, text wrapping, scrollback, reflow. SIMD-optimized parsing. No renderer — you provide your own.
- **libghostty (full)** — adds Metal/OpenGL rendering, font handling, PTY management, input encoding. "Provide us with a Metal surface and we'll handle the rest."

## Current status (verified 2026-04-10)

- **libghostty-vt C API** — available and usable for Zig and C; compatible with macOS, Linux, Windows, and WebAssembly. Internal functionality is extremely stable but **API signatures are still in flux**. No stable version has been tagged ("We haven't tagged libghostty with a version yet").
- **Docs** — the Ghostty team publishes a Doxygen site covering the C API; the docs experience is still being improved.
- **libghostty-spm** — community-maintained Swift Package wrapping a prebuilt `GhosttyKit.xcframework`. Status changes frequently; verify against the upstream repo before committing to a specific tag.
- **Ghostty macOS app** — production reference implementation of Swift + AppKit consuming the libghostty C API.
- **Ghostling** — minimal complete terminal emulator in a single C file using libghostty + Raylib. The smallest readable example of the API surface.

Until libghostty is tagged, treat any Swift integration as a moving target. Pin to a specific commit and audit the header diff on upgrades.

## Architecture pattern

```
┌─────────────────────────────────────────┐
│  Your Swift app (AppKit + SwiftUI)       │
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

### Ownership split

**libghostty owns:**
- Terminal emulation (VT sequence parsing, terminal state)
- Metal rendering (multi-pass cell rendering)
- PTY creation and management
- Font rasterization to texture atlas
- Shell integration scripts (bash, zsh, fish)
- Keyboard input encoding

**Host app owns:**
- Window and view lifecycle (`NSWindow`, `NSView`)
- Providing the `NSView`/`CAMetalLayer` surface
- Input event forwarding (`NSEvent` → libghostty)
- Layout and positioning of terminal surfaces
- Tabs, splits, and multi-window management
- Application-level features (search, settings, command palette, etc.)

## Surface lifecycle

A "surface" is a single terminal instance. The word "surface" in this doc always refers to a libghostty terminal surface, not a canvas viewport (see `advanced-rendering.md` for canvas terminology).

```
1. Create surface (ghostty_surface_new or equivalent)
   - Host provides NSView handle to libghostty
   - libghostty creates CAMetalLayer, PTY, IO thread, render thread

2. Forward events
   - Keyboard: NSEvent → ghostty_surface_key_event()
   - Mouse:    NSEvent → ghostty_surface_mouse_event()
   - Resize:   layout change → ghostty_surface_set_size()

3. Destroy surface
   - ghostty_surface_free()
   - Tears down threads, closes PTY
```

### Surface inside an NSView

```swift
// PSEUDOCODE — actual libghostty API signatures drift; verify against
// the version you're linking against. Do not copy-paste this verbatim.
final class TerminalSurfaceView: NSView {
    private var surface: OpaquePointer?  // ghostty_surface_t

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { nil }

    func createSurface(config: OpaquePointer) {
        // libghostty takes this NSView and creates the Metal layer internally
        surface = ghostty_surface_new(config, Unmanaged.passUnretained(self).toOpaque())
    }

    override func keyDown(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_key_event(surface, /* key event data */)
    }

    override func layout() {
        super.layout()
        guard let surface else { return }
        let size = convertToBacking(bounds).size
        ghostty_surface_set_size(surface, UInt32(size.width), UInt32(size.height))
    }

    // Implement NSTextInputClient for CJK/emoji composition —
    // required for input method editor (IME) support.

    deinit {
        if let surface { ghostty_surface_free(surface) }
    }
}
```

## Threading model

Each terminal surface runs three threads:

```
Main thread (shared)
    AppKit event loop, gesture handling, layout, SwiftUI updates

Per-surface IO thread
    PTY read() loop, VT sequence parsing, terminal state updates,
    shell integration event handling

Per-surface render thread
    Reads terminal state (synchronized), updates GPU buffers
    (cell data, atlas), encodes Metal command buffer, presents
```

Communication between threads uses lock-free ring buffers for data and semaphores for frame synchronization. The host app never touches the IO or render threads directly — it interacts only on the main thread via the C API.

## Rendering pipeline (Ghostty's approach)

Multi-pass, back-to-front, per frame:

1. **Backgrounds** — colored rectangles for cells with non-default background colors. Simple instanced quad rendering.
2. **Cell text** — the complex pass. For each visible cell:
   - Look up the glyph in the texture atlas (rasterize if not cached)
   - Pack cell data into a GPU-optimized `CellText` struct (32 bytes): grid position, glyph atlas coordinates, foreground/background color, style flags
   - Upload as an instance buffer
   - Draw instanced quads sampling from the atlas texture
3. **Cursor** — renders the cursor shape (block, underline, bar) at the current position.
4. **Post-processing** (optional) — user-provided custom shaders (MSL) for visual effects (CRT, blur, etc.).

Swap chain: triple-buffered on Metal. A semaphore prevents the CPU from overwriting GPU-in-use buffers. `nextFrame()` waits on the semaphore to acquire an available frame state.

## Multi-terminal canvas integration

For a canvas of terminals, each terminal becomes a `CanvasObject` (see `advanced-rendering.md` for the canvas model). At full LOD the terminal surface renders to its own Metal layer; at thumbnail LOD you composite a cached snapshot.

```swift
// PSEUDOCODE — the exact API depends on libghostty version.
final class TerminalTile: CanvasObject {
    let id = UUID()
    var worldPosition: SIMD2<Float>
    var worldSize: SIMD2<Float> = SIMD2(800, 600)
    var zIndex: Int = 0

    private var surface: OpaquePointer?
    private var surfaceView: TerminalSurfaceView?
    private var cachedTexture: MTLTexture?

    func render(encoder: MTLRenderCommandEncoder, camera: Camera, lod: LODLevel) {
        switch lod {
        case .full:
            // libghostty renders to its own Metal layer; position the NSView
            updateSurfaceViewFrame(camera: camera)
        case .thumbnail:
            if cachedTexture == nil || isDirty {
                cachedTexture = captureCurrentFrame()
            }
            if let tex = cachedTexture {
                drawTexturedQuad(encoder: encoder, texture: tex, camera: camera)
            }
        case .placeholder:
            drawColoredRect(encoder: encoder, camera: camera)
        }
    }
}
```

## PTY piping between terminals

"Piping" from Terminal A to Terminal B means routing A's stdout to B's stdin using the underlying file descriptors:

```swift
final class TerminalPipe {
    let source: TerminalTile
    let target: TerminalTile
    private var pipeTask: Task<Void, Never>?

    func activate() {
        pipeTask = Task.detached { [source, target] in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }

            while !Task.isCancelled {
                let bytesRead = read(source.ptyReadFd, buffer, 4096)
                if bytesRead > 0 {
                    write(target.ptyWriteFd, buffer, bytesRead)
                } else if bytesRead == 0 {
                    break  // EOF
                }
            }
        }
    }

    func deactivate() { pipeTask?.cancel() }
}
```

`Task.isCancelled` is the Swift-native way to bail out of a long-running loop; don't use `Thread.current.isCancelled` in new code.

## Key files in Ghostty source

Study these in [github.com/ghostty-org/ghostty](https://github.com/ghostty-org/ghostty):

| File | Purpose |
|------|---------|
| `macos/Sources/App/` | Swift app entry point, `NSApplicationDelegate` |
| `macos/Sources/Ghostty/SurfaceView.swift` | `NSView` hosting a terminal surface |
| `macos/Sources/Ghostty/Ghostty.Config.swift` | Swift wrapper around the C config API |
| `src/Surface.zig` | Core surface abstraction |
| `src/renderer/Metal.zig` | Metal backend — swap chain, passes, frame state |
| `src/renderer/metal/shaders.zig` | Shader definitions, `CellText` struct |
| `src/renderer/metal/cell.zig` | Cell rendering logic |
| `src/termio/Termio.zig` | Terminal IO thread |
| `src/terminal/Terminal.zig` | Terminal state machine |
| `src/apprt/embedded.zig` | Embedded library mode (how host apps consume libghostty) |
| `src/font/main.zig` | Font loading and atlas management |

## Related projects

- **Ghostling** ([github.com/ghostty-org/ghostling](https://github.com/ghostty-org/ghostling)) — minimal `~600 LOC` C example; the shortest readable libghostty consumer
- **Kytos** — macOS terminal built on libghostty; small enough to read end-to-end
- **[awesome-libghostty](https://github.com/Uzaaft/awesome-libghostty)** — curated list of libghostty consumers across platforms and languages; check here for up-to-date examples

## Integration checklist

1. Pin to a specific libghostty commit (no stable version yet; see status section above)
2. Add `libghostty-spm` as a Swift Package dependency or link the `GhosttyKit.xcframework` directly
3. Import `GhosttyKit`
4. Create a `TerminalSurfaceView` subclass of `NSView`; call `ghostty_surface_new` passing the view handle
5. Forward keyboard (`keyDown`, `keyUp`), mouse (`mouseDown`, `mouseMoved`, `scrollWheel`), and resize events to the corresponding `ghostty_surface_*` functions
6. Implement `NSTextInputClient` for IME support (CJK, emoji, dead keys)
7. Handle surface lifecycle — `ghostty_surface_free` in `deinit` and on explicit close
8. Read the Doxygen-generated C API reference for the version you're linking against

## Resources

- [mitchellh.com/writing/libghostty-is-coming](https://mitchellh.com/writing/libghostty-is-coming) — the original announcement
- [github.com/ghostty-org/ghostty](https://github.com/ghostty-org/ghostty) — main repo; check `include/ghostty.h` for the current C API
- [github.com/ghostty-org/ghostling](https://github.com/ghostty-org/ghostling) — minimal C reference
- [github.com/Uzaaft/awesome-libghostty](https://github.com/Uzaaft/awesome-libghostty) — ecosystem directory
