---
name: macos-native-canvas
description: "Build native macOS desktop applications using Swift, Metal, and AppKit with optional libghostty integration for terminal embedding. Use this skill when: building macOS apps with GPU-accelerated rendering, creating infinite canvas UIs, embedding terminal emulators via libghostty, working with CAMetalLayer or MTKView, deciding between AppKit and SwiftUI, setting up Metal render pipelines in Swift, building hybrid AppKit+SwiftUI architectures, working with PTY/terminal plumbing, or any macOS native development involving custom rendering, canvas views, or GPU compute. Also trigger for questions about Swift from a TypeScript/Python developer's perspective, Metal shader pipelines, or Ghostty source code architecture."
---

# macOS Native Canvas Development

Build high-performance native macOS apps with Swift + Metal + AppKit, with optional libghostty terminal embedding. Optimized for developers coming from TypeScript/Python.

## Architecture Decision: AppKit + SwiftUI Hybrid

**Always use the hybrid pattern.** Pure SwiftUI cannot handle custom Metal rendering, fine-grained gesture control, or low-level window management. Pure AppKit is too verbose for standard UI chrome.

```
┌─────────────────────────────────────────┐
│  App Lifecycle (AppKit)                  │
│  NSApplicationDelegate, NSWindow        │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │  Window Chrome (SwiftUI)           │  │
│  │  Toolbar, sidebar, settings,       │  │
│  │  inspector panels, menus           │  │
│  │                                    │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Canvas View (AppKit NSView) │  │  │
│  │  │  CAMetalLayer, gestures,     │  │  │
│  │  │  render loop, Metal pipeline │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### What goes where

**AppKit owns:** App lifecycle (`NSApplicationDelegate`), window creation (`NSWindow`), the Metal canvas view (custom `NSView` subclass with `CAMetalLayer`), low-level event handling (keyboard, mouse, trackpad gestures at canvas level), screen capture APIs (`ScreenCaptureKit`, `CGWindowListCreateImage`), borderless/transparent windows, and any `NSView` that hosts a `CAMetalLayer`.

**SwiftUI owns:** Toolbar/sidebar UI, settings/preferences windows, inspector panels, form-like UI (configuration, settings), overlay HUDs, menu bar items, and any standard control-based interface.

**Bridging:** Use `NSHostingView` to embed SwiftUI inside AppKit (preferred direction — AppKit outward, SwiftUI inward). Use `NSViewRepresentable` only when the top-level container must be SwiftUI.

### Why not pure SwiftUI for canvas/rendering apps

- `NSViewRepresentable` wrapping Metal views has lifecycle issues — the contract between SwiftUI's layout engine and `CAMetalLayer.drawableSize` causes blurry or clipped rendering if not carefully managed.
- SwiftUI gesture composition (simultaneous pan + zoom + click-through) is unreliable on macOS compared to AppKit's `NSGestureRecognizer`.
- SwiftUI's view diffing is wrong abstraction for render-loop-driven canvases. A canvas is not a view hierarchy — it's a GPU draw call per frame.
- Custom window management (borderless, transparent overlays, screen coordinates) requires AppKit APIs with no SwiftUI equivalent.

---

## Swift for TypeScript/Python Developers

Read `references/swift-for-ts-devs.md` for a complete syntax mapping. Key differences:

- `let` = immutable (TS `const`), `var` = mutable (TS `let`) — **the keywords are swapped**
- Types are real at runtime, not erased like TypeScript
- Optionals (`String?`) replace null/undefined — compiler-enforced unwrapping
- Structs (value types, copied on assignment) vs Classes (reference types) — prefer structs
- Protocols = interfaces with default implementations via extensions
- Enums carry associated values (like TS discriminated unions, but built-in)
- `async`/`await` exists but has a more complex isolation model than JS
- ARC (Automatic Reference Counting) instead of garbage collection — deterministic deallocation
- String interpolation: `\(variable)` instead of `${variable}`

---

## Metal Rendering Pipeline

Read `references/metal-pipeline.md` for detailed setup. Core concepts:

### Mental model (maps to WebGPU)

| Metal | WebGPU Equivalent | Purpose |
|-------|-------------------|---------|
| `MTLDevice` | `GPUDevice` | GPU handle |
| `MTLCommandQueue` | `GPUQueue` | Submits work |
| `MTLCommandBuffer` | `GPUCommandBuffer` | Batch of commands |
| `MTLRenderCommandEncoder` | `GPURenderPassEncoder` | Encodes draw calls |
| `MTLRenderPipelineState` | `GPURenderPipeline` | Compiled shader pipeline |
| `MTLBuffer` | `GPUBuffer` | GPU memory |
| `MTLTexture` | `GPUTexture` | Image data |
| `CAMetalLayer` | Canvas + `GPUCanvasContext` | Drawable surface |
| Metal Shading Language (MSL) | WGSL | Shader language (C++-based) |

### Minimal Metal setup in AppKit

```swift
import AppKit
import Metal
import QuartzCore

class MetalCanvasView: NSView {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var metalLayer: CAMetalLayer!
    private var displayLink: CVDisplayLink?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupMetal()
    }

    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!

        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        wantsLayer = true
        layer = metalLayer

        setupDisplayLink()
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, { _, _, _, _, _, context in
            let view = Unmanaged<MetalCanvasView>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async { view.render() }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink!)
    }

    func render() {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = drawable.texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        passDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        // Draw calls go here
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    override func layout() {
        super.layout()
        metalLayer.drawableSize = convertToBacking(bounds).size
    }

    required init?(coder: NSCoder) { fatalError() }
}
```

---

## Infinite Canvas Architecture

Read `references/infinite-canvas.md` for full architecture. Core concepts:

### Data model

An infinite canvas = a camera (position + zoom) viewing an unbounded 2D coordinate space. Every object has a world-space position. The camera transform (3x3 affine matrix) converts world → screen coordinates.

```swift
struct Camera {
    var position: SIMD2<Float> = .zero  // World-space center
    var zoom: Float = 1.0               // Scale factor

    var viewMatrix: float3x3 {
        let scale = float3x3(diagonal: SIMD3(zoom, zoom, 1))
        let translate = float3x3(columns: (
            SIMD3(1, 0, 0),
            SIMD3(0, 1, 0),
            SIMD3(-position.x, -position.y, 1)
        ))
        return scale * translate
    }
}
```

### Level of Detail (LOD)

For canvases with many embedded views (e.g., terminal tiles):

1. **Full fidelity** — objects near viewport at close zoom get full GPU rendering
2. **Thumbnail** — visible but zoomed-out objects render to cached offscreen texture, displayed as textured quad
3. **Placeholder** — distant objects render as colored rectangle with label

### Spatial partitioning

Use a quadtree or spatial hash to quickly find which objects intersect the viewport. For axis-aligned rectangles of known size, a simple grid-based spatial hash is sufficient.

### Render loop

```
Each frame:
  1. Update camera from gesture input (pan/zoom)
  2. Frustum cull: which objects intersect viewport?
  3. For each visible object, determine LOD tier
  4. Render back-to-front: backgrounds → content → connections → UI overlay
  5. Submit Metal command buffer
```

---

## libghostty Integration

Read `references/libghostty-integration.md` for detailed integration guide.

### Architecture

Ghostty's architecture is the reference pattern for embedding terminals:

- **libghostty-vt**: Zero-dependency C/Zig library for VT sequence parsing and terminal state
- **libghostty (full)**: Includes rendering, font handling, PTY management
- **C API**: The integration boundary — Swift calls C functions exported by Zig
- **libghostty-spm**: Prebuilt `GhosttyKit.xcframework` as a Swift Package

### Key pattern: Swift consuming a C library

```swift
// Swift calls C API exported by Zig-compiled static library
// The host app provides an NSView surface, libghostty handles:
//   - Terminal emulation (VT parsing, state)
//   - Metal rendering (cell text, cursor, backgrounds)
//   - PTY management
//   - Shell integration

// The host app is responsible for:
//   - Window/view lifecycle
//   - Input event forwarding
//   - Layout and positioning of terminal surfaces
```

### Threading model (per terminal surface)

```
Main thread:       AppKit event loop, gesture handling, layout
IO thread:         PTY read/write (per terminal)
Render thread:     Metal command buffer encoding (per terminal)
Pipe orchestrator: Routes data between terminal PTYs (app-level)
```

### Multi-terminal piping

A "pipe" between Terminal A → Terminal B = read stdout from A's PTY fd, write to stdin of B's PTY fd. This is Unix file descriptor plumbing:

```swift
// Conceptual — actual implementation depends on libghostty API
var pipeFds: [Int32] = [0, 0]
pipe(&pipeFds)
// pipeFds[0] = read end → connect to Terminal B's stdin
// pipeFds[1] = write end → connect to Terminal A's stdout
```

### Ghostty source code map

Key files to study in `github.com/ghostty-org/ghostty`:

| Path | What it teaches |
|------|-----------------|
| `macos/` | Swift app consuming C API, surface lifecycle |
| `src/renderer/Metal.zig` | Metal swap chain, frame state, render passes |
| `src/renderer/metal/shaders.zig` | Shader pipelines, CellText struct (32 bytes, GPU-optimized) |
| `src/Surface.zig` | Core surface abstraction bridging terminal/IO/rendering |
| `src/apprt/embedded.zig` | Embedded library mode (how Swift app consumes libghostty) |

### Rendering pipeline (Ghostty's approach)

Multi-pass, back-to-front:
1. Background colors pass
2. Cell text pass (texture atlas sampling, glyph compositing)
3. Cursor pass
4. Custom post-processing shaders (optional, user-provided MSL)

Swap chain: 3 frame states for Metal (triple buffering), semaphore prevents CPU overwriting GPU-in-use buffers.

---

## Project Setup Checklist

### New macOS app with Metal canvas

1. Create Xcode project → macOS → App
2. Set deployment target (macOS 13+ for modern Metal features)
3. Add `Metal.framework` and `MetalKit.framework`
4. Create `AppDelegate.swift` with `NSApplicationDelegate`
5. Create custom `NSView` subclass with `CAMetalLayer`
6. Set up `CVDisplayLink` for render loop
7. Create `NSWindow` programmatically (for full control) or via storyboard
8. Bridge SwiftUI panels via `NSHostingView` for chrome

### Adding libghostty

1. Add `libghostty-spm` Swift Package dependency
2. Import `GhosttyKit` framework
3. Create terminal surface via C API
4. Provide `NSView` + `CAMetalLayer` to libghostty
5. Forward keyboard/mouse events to libghostty
6. Handle surface lifecycle (create/destroy on tab/split operations)

### Package.swift structure

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TerminalCanvas",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Add libghostty-spm when ready
        // .package(url: "https://github.com/.../libghostty-spm.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "TerminalCanvas",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
```

---

## Key Resources

- **Ghostty source**: github.com/ghostty-org/ghostty
- **Ghostling** (minimal libghostty example): github.com/ghostty-org/ghostling
- **awesome-libghostty**: github.com/Uzaaft/awesome-libghostty
- **Metal by Example** (best Metal tutorial): metalbyexample.com
- **Apple Metal sample code**: developer.apple.com/metal/sample-code/
- **Hacking with macOS** (AppKit patterns): hackingwithswift.com/books/macos
- **try! Swift Tokyo 2025**: MSDF + Metal infinite canvas talk by Michael Petrie
- **libghostty announcement**: mitchellh.com/writing/libghostty-is-coming
- **Kytos** (libghostty macOS terminal): Full production example of Swift + libghostty
- **Metal 4** (WWDC 2025): Unified command encoder, neural rendering
- **Swift 6.2 Approachable Concurrency**: Default to @MainActor, opt-in parallelism
