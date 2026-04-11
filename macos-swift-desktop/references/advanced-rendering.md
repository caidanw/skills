# Advanced Rendering: Metal, Infinite Canvas, WKWebView

This reference covers GPU-accelerated rendering and view embedding for desktop apps that need to go beyond standard AppKit/SwiftUI controls: Metal pipelines, infinite canvases, and hosting WKWebView instances inside an AppKit layout.

For embedding a terminal via libghostty, read `libghostty-integration.md` — this doc covers the generic patterns.

## Table of contents

- [When you need this](#when-you-need-this)
- [Metal in an AppKit view](#metal-in-an-appkit-view)
- [Shader pipeline](#shader-pipeline)
- [Triple buffering](#triple-buffering)
- [Offscreen rendering (for cached thumbnails)](#offscreen-rendering-for-cached-thumbnails)
- [Alpha blending](#alpha-blending)
- [Text rendering approaches](#text-rendering-approaches)
- [Infinite canvas: camera, hit testing, culling](#infinite-canvas-camera-hit-testing-culling)
- [Spatial hash for frustum culling](#spatial-hash-for-frustum-culling)
- [Connection rendering](#connection-rendering)
- [Render loop for a canvas](#render-loop-for-a-canvas)
- [WKWebView embedding in AppKit](#wkwebview-embedding-in-appkit)
- [Performance considerations](#performance-considerations)

## When you need this

You need this doc if you're doing **any** of:

- Drawing to a custom surface with Metal (`CAMetalLayer`, `MTKView`)
- Rendering text, images, or shapes where standard SwiftUI/AppKit performance isn't good enough (thousands of cells, millions of vertices)
- Building an infinite/zoomable canvas with pan/zoom gestures
- Embedding a `WKWebView` (or multiple) inside a native layout
- Level-of-detail rendering where offscreen objects become cached textures or placeholders

You do **not** need this for typical forms, sidebars, or inspectors — standard SwiftUI or AppKit is faster to build and perfectly adequate.

## Metal in an AppKit view

### `CAMetalLayer` vs `MTKView`

- **`CAMetalLayer`** — raw Metal surface. You own the display link, frame timing, and resize. Use this for custom renderers, infinite canvases, or embedding Metal in complex view hierarchies where `MTKView`'s assumptions get in the way.
- **`MTKView`** — `NSView` subclass that manages a `CAMetalLayer`, display link, and resize for you. Good for getting started and simple cases. Implements `MTKViewDelegate` with a `draw(in:)` callback.

Start with `MTKView` unless you need precise control. Move to raw `CAMetalLayer` when you hit its limits.

### Minimal `CAMetalLayer`-backed `NSView`

```swift
import AppKit
import Metal
import QuartzCore

final class MetalCanvasView: NSView {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let metalLayer: CAMetalLayer
    private var displayLink: CVDisplayLink?

    init?(frame: NSRect) {
        // Fail initialization cleanly if Metal is unavailable (old hardware, VMs)
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = queue
        self.metalLayer = CAMetalLayer()
        super.init(frame: frame)

        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        wantsLayer = true
        layer = metalLayer

        setupDisplayLink()
    }

    required init?(coder: NSCoder) { nil }

    private func setupDisplayLink() {
        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let dl else { return }
        // Parameters: (displayLink, inNow, inOutputTime, flagsIn, flagsOut, context).
        // All ignored — we don't need precise presentation timing, we render on the
        // next main-queue turn. A production render loop would use `inOutputTime`.
        CVDisplayLinkSetOutputCallback(dl, { _, _, _, _, _, context in
            // `context` is the opaque self pointer we passed below; it is
            // guaranteed non-nil for this call site, but guard anyway so a
            // later refactor doesn't turn it into a latent crash.
            guard let context else { return kCVReturnSuccess }
            let view = Unmanaged<MetalCanvasView>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { view.render() }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(dl)
        displayLink = dl
    }

    func render() {
        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        // Draw calls go here.
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    override func layout() {
        super.layout()
        metalLayer.drawableSize = convertToBacking(bounds).size
    }

    deinit {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
    }
}
```

Key points:
- `MTLCreateSystemDefaultDevice()` returns `nil` on VMs and very old Macs — treat it as a fallible operation.
- `drawableSize` is in **pixels**, not points. Use `convertToBacking(_:)` to go from points → pixels.
- Always stop the display link in `deinit` or the render loop keeps running.

## Shader pipeline

### Metal Shading Language (MSL) basics

MSL is a C++14-based language. Shaders live in `.metal` files compiled by Xcode as part of the default Metal library.

```metal
// Shaders.metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 viewProjectionMatrix;
};

vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexOut out;
    out.position = uniforms.viewProjectionMatrix * float4(in.position, 0.0, 1.0);
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}
```

### Creating a pipeline state

```swift
func makePipeline() throws -> MTLRenderPipelineState {
    guard let library = device.makeDefaultLibrary() else {
        throw RenderError.noDefaultLibrary
    }
    guard let vertexFn = library.makeFunction(name: "vertex_main"),
          let fragmentFn = library.makeFunction(name: "fragment_main") else {
        throw RenderError.missingShaderFunction
    }

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFn
    descriptor.fragmentFunction = fragmentFn
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float2  // position
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[1].format = .float4  // color
    vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
    vertexDescriptor.attributes[1].bufferIndex = 0
    vertexDescriptor.layouts[0].stride =
        MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride

    descriptor.vertexDescriptor = vertexDescriptor

    return try device.makeRenderPipelineState(descriptor: descriptor)
}
```

### Passing uniforms

For small uniform buffers (under 4KB), `setVertexBytes(_:length:index:)` is cheaper than allocating an `MTLBuffer`:

```swift
struct Uniforms {
    var viewProjectionMatrix: float4x4
}

func render() {
    var uniforms = Uniforms(viewProjectionMatrix: camera.viewProjectionMatrix)
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
}
```

## Triple buffering

For smooth rendering, use multiple frame states so the CPU can encode frame N+1 while the GPU renders frame N without contention:

```swift
let maxFramesInFlight = 3
let frameSemaphore = DispatchSemaphore(value: maxFramesInFlight)
var currentFrameIndex = 0

func render() {
    frameSemaphore.wait()

    let commandBuffer = commandQueue.makeCommandBuffer()!
    commandBuffer.addCompletedHandler { [weak self] _ in
        self?.frameSemaphore.signal()
    }

    // Use currentFrameIndex to select per-frame uniform/vertex buffers
    let uniformBuffer = uniformBuffers[currentFrameIndex]
    // ... encode commands using uniformBuffer ...

    commandBuffer.present(drawable)
    commandBuffer.commit()

    currentFrameIndex = (currentFrameIndex + 1) % maxFramesInFlight
}
```

The semaphore prevents frame N+3 from starting until frame N finishes, capping latency and preventing CPU-side buffer overwrites while the GPU is mid-render.

## Offscreen rendering (for cached thumbnails)

When an object becomes too small to render at full fidelity, render it once to an offscreen texture and display that texture as a quad until the object's content changes:

```swift
func renderToTexture(size: CGSize) -> MTLTexture? {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm,
        width: Int(size.width),
        height: Int(size.height),
        mipmapped: false
    )
    descriptor.usage = [.renderTarget, .shaderRead]

    guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store

    // Encode draw calls targeting `pass` instead of the drawable.
    // The resulting texture can now be sampled in the main pass.

    return texture
}
```

## Alpha blending

For overlays, connection lines, and semi-transparent UI on top of a Metal canvas:

```swift
descriptor.colorAttachments[0].isBlendingEnabled = true
descriptor.colorAttachments[0].rgbBlendOperation = .add
descriptor.colorAttachments[0].alphaBlendOperation = .add
descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
```

## Text rendering approaches

1. **Texture atlas** (Ghostty's approach) — rasterize glyphs to a GPU texture atlas on first use, sample in the fragment shader. Fast and simple. The atlas has a fixed resolution, so text can look blurry at non-native zoom levels.
2. **MSDF (Multi-channel Signed Distance Fields)** — resolution-independent text. Sharp at any zoom level. Ideal for infinite canvases where zoom varies wildly. Setup is more complex (pre-generate MSDF atlas at build time, custom shader). See the try! Swift Tokyo 2025 talk by Michael Petrie.
3. **Core Text + offscreen render** — render text with `CTFramesetter` to a `CGContext`, upload the result as a texture. Simple, but CPU-bound and doesn't scale to many text elements.

Pick texture atlas for fixed zoom, MSDF for infinite canvas with wide zoom range.

## Infinite canvas: camera, hit testing, culling

An infinite canvas is a viewport (camera) looking into an unbounded 2D coordinate space. Objects live in world space. The camera transform converts world → screen coordinates. Pan = translate camera. Zoom = scale camera.

```swift
struct Camera {
    var position: SIMD2<Float> = .zero   // World-space center
    var zoom: Float = 1.0                // Scale factor
    var screenSize: SIMD2<Float> = .zero // Viewport size in pixels

    /// World → Screen transform. Pass to GPU as a uniform.
    /// Assumes `simd` matrix initializers; replace with literal float4x4 columns
    /// if you haven't pulled in Apple's sample matrix extensions.
    var viewMatrix: float4x4 {
        let scale = float4x4(diagonal: SIMD4(zoom, zoom, 1, 1))
        var translate = matrix_identity_float4x4
        translate.columns.3.x = -position.x * zoom + screenSize.x / 2
        translate.columns.3.y = -position.y * zoom + screenSize.y / 2
        return translate * scale
    }

    /// Screen → World. Used for hit testing and placing new objects.
    func screenToWorld(_ screenPoint: CGPoint) -> SIMD2<Float> {
        let x = (Float(screenPoint.x) - screenSize.x / 2) / zoom + position.x
        let y = (Float(screenPoint.y) - screenSize.y / 2) / zoom + position.y
        return SIMD2(x, y)
    }

    /// Visible world-space bounds. Used for frustum culling.
    var visibleRect: CGRect {
        let halfWidth = screenSize.x / (2 * zoom)
        let halfHeight = screenSize.y / (2 * zoom)
        return CGRect(
            x: CGFloat(position.x - halfWidth),
            y: CGFloat(position.y - halfHeight),
            width: CGFloat(halfWidth * 2),
            height: CGFloat(halfHeight * 2)
        )
    }
}
```

### Pan and zoom gestures (AppKit)

```swift
final class CanvasView: NSView {
    var camera = Camera()

    override func magnify(with event: NSEvent) {
        // Pinch to zoom — zoom toward cursor position
        let cursorWorld = camera.screenToWorld(convert(event.locationInWindow, from: nil))
        let oldZoom = camera.zoom
        camera.zoom = max(0.1, min(camera.zoom * Float(1.0 + event.magnification), 10.0))

        // Adjust position so the point under the cursor stays fixed in world space
        let zoomRatio = camera.zoom / oldZoom
        camera.position.x = cursorWorld.x + (camera.position.x - cursorWorld.x) / zoomRatio
        camera.position.y = cursorWorld.y + (camera.position.y - cursorWorld.y) / zoomRatio
    }

    override func scrollWheel(with event: NSEvent) {
        // Two-finger scroll to pan (divide by zoom so pan speed matches cursor speed)
        camera.position.x -= Float(event.scrollingDeltaX) / camera.zoom
        camera.position.y -= Float(event.scrollingDeltaY) / camera.zoom
    }

    override func mouseDown(with event: NSEvent) {
        let worldPoint = camera.screenToWorld(convert(event.locationInWindow, from: nil))
        // Hit test against canvas objects at worldPoint
    }
}
```

Use AppKit gesture overrides (`magnify`, `scrollWheel`, `mouseDown`) rather than `NSGestureRecognizer` or SwiftUI gestures — the overrides compose reliably and give you pixel-accurate event data.

### Canvas object model with level of detail

Pick ONE term — this doc uses **"canvas"** for the application-level coordinate space and **LOD level** for rendering detail. Reserve **"surface"** for libghostty terminal surfaces (`references/libghostty-integration.md`).

```swift
protocol CanvasObject: AnyObject {
    var id: UUID { get }
    var worldPosition: SIMD2<Float> { get set }
    var worldSize: SIMD2<Float> { get }
    var zIndex: Int { get }

    func render(encoder: MTLRenderCommandEncoder, camera: Camera, lod: LODLevel)
}

enum LODLevel {
    case full         // Close zoom — full fidelity rendering
    case thumbnail    // Medium zoom — cached texture sampled as a quad
    case placeholder  // Far zoom — colored rectangle with a label
}

final class CanvasState {
    var objects: [UUID: CanvasObject] = [:]
    var connections: [Connection] = []
    var camera = Camera()
    var spatialIndex = SpatialHash<CanvasObject>(cellSize: 500)

    func visibleObjects() -> [CanvasObject] {
        spatialIndex
            .query(rect: camera.visibleRect)
            .sorted { $0.zIndex < $1.zIndex }
    }

    func lodLevel(for object: CanvasObject) -> LODLevel {
        let screenSize = object.worldSize * camera.zoom
        let screenArea = screenSize.x * screenSize.y
        if screenArea > 10_000 { return .full }
        if screenArea > 500 { return .thumbnail }
        return .placeholder
    }
}
```

## Spatial hash for frustum culling

For axis-aligned objects, a grid-based spatial hash is simpler and faster than a quadtree for typical canvas sizes:

```swift
final class SpatialHash<T: CanvasObject> {
    let cellSize: Float
    private var cells: [SIMD2<Int32>: [T]] = [:]

    init(cellSize: Float) { self.cellSize = cellSize }

    private func cellKey(for point: SIMD2<Float>) -> SIMD2<Int32> {
        SIMD2(Int32(floor(point.x / cellSize)), Int32(floor(point.y / cellSize)))
    }

    func insert(_ object: T) {
        let minKey = cellKey(for: object.worldPosition)
        let maxKey = cellKey(for: object.worldPosition + object.worldSize)
        for x in minKey.x...maxKey.x {
            for y in minKey.y...maxKey.y {
                cells[SIMD2(x, y), default: []].append(object)
            }
        }
    }

    func query(rect: CGRect) -> [T] {
        let minKey = cellKey(for: SIMD2(Float(rect.minX), Float(rect.minY)))
        let maxKey = cellKey(for: SIMD2(Float(rect.maxX), Float(rect.maxY)))
        var seen: Set<ObjectIdentifier> = []
        var result: [T] = []
        for x in minKey.x...maxKey.x {
            for y in minKey.y...maxKey.y {
                for obj in cells[SIMD2(x, y)] ?? [] where seen.insert(ObjectIdentifier(obj)).inserted {
                    result.append(obj)
                }
            }
        }
        return result
    }

    func clear() { cells.removeAll(keepingCapacity: true) }
}
```

Rebuild the hash on world changes, or incrementally update cells when objects move. `cellSize` should be roughly the average object size — too small and you hash the same object into many cells; too large and the query degenerates to a linear scan.

## Connection rendering

For connections between canvas objects (pipes, edges, references):

```swift
struct Connection {
    let sourceId: UUID
    let targetId: UUID

    func controlPoints(source: CanvasObject, target: CanvasObject) -> (
        start: SIMD2<Float>, cp1: SIMD2<Float>,
        cp2: SIMD2<Float>, end: SIMD2<Float>
    ) {
        let start = source.worldPosition + SIMD2(source.worldSize.x, source.worldSize.y / 2)
        let end = target.worldPosition + SIMD2(0, target.worldSize.y / 2)
        let dx = abs(end.x - start.x) * 0.5
        let cp1 = SIMD2(start.x + dx, start.y)
        let cp2 = SIMD2(end.x - dx, end.y)
        return (start, cp1, cp2, end)
    }
}
```

Render curves one of three ways:

1. **GPU tessellation** — convert Bézier to line segments in a vertex shader, draw as a triangle strip with width. Highest performance; most complex shader.
2. **Core Graphics overlay** — draw curves in a separate `NSView` layered above the Metal canvas. Simplest; costs a second render path but fine for hundreds of connections.
3. **Instanced line rendering** — pre-tessellate on CPU, upload as a vertex buffer, draw with instancing. Middle ground.

Start with (2) and graduate to (1) or (3) only if profiling shows the overlay is the bottleneck.

## Render loop for a canvas

```swift
func render() {
    let visible = canvasState.visibleObjects()

    guard let drawable = metalLayer.nextDrawable(),
          let commandBuffer = commandQueue.makeCommandBuffer() else { return }

    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
    pass.colorAttachments[0].storeAction = .store

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

    // Pass 1: object bodies (back to front for correct alpha)
    for object in visible {
        let lod = canvasState.lodLevel(for: object)
        object.render(encoder: encoder, camera: canvasState.camera, lod: lod)
    }

    // Pass 2: connections
    for connection in canvasState.connections {
        renderConnection(connection, encoder: encoder)
    }

    // Pass 3: selection handles / UI overlay
    renderSelectionHandles(encoder: encoder)

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
}
```

## WKWebView embedding in AppKit

`WKWebView` is the standard way to embed web content in a native macOS app. Each instance is expensive (it launches a web content process), so share a `WKProcessPool` across related instances and tear down views that go offscreen.

### Minimal embedded web view

```swift
import AppKit
import WebKit

final class EmbeddedWebView: NSView {
    private let webView: WKWebView

    override init(frame: NSRect) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")  // Web Inspector
        self.webView = WKWebView(frame: frame, configuration: config)
        super.init(frame: frame)

        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
    }

    required init?(coder: NSCoder) { nil }

    func loadURL(_ url: URL) { webView.load(URLRequest(url: url)) }
    func loadHTML(_ html: String, baseURL: URL? = nil) { webView.loadHTMLString(html, baseURL: baseURL) }
}
```

Declaring `webView` as a non-optional `let` avoids the force-unwrap pattern that tends to creep in with `WKWebView` setup.

### Swift → JavaScript

Call into web content with `evaluateJavaScript(_:)`. Use `async`/`await` on macOS 12+:

```swift
// Simple call
let title = try await webView.evaluateJavaScript("document.title") as? String

// Calling a function with JSON-serialized data (safer than string interpolation)
func sendToJS(event: String, data: [String: Any]) async throws {
    let json = try JSONSerialization.data(withJSONObject: data)
    let jsonString = String(decoding: json, as: UTF8.self)
    _ = try await webView.evaluateJavaScript(
        "window.onNativeEvent(\(escapeJSString(event)), \(jsonString))"
    )
}
```

Never string-concatenate user input into the JavaScript source — it's XSS-in-your-own-app. Always `JSONSerialization` your payloads.

### JavaScript → Swift

Register a `WKScriptMessageHandler`:

```swift
final class WebBridge: NSObject, WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        switch action {
        case "resize":
            let w = body["width"] as? CGFloat ?? 0
            let h = body["height"] as? CGFloat ?? 0
            handleResize(width: w, height: h)
        case "navigate":
            if let url = body["url"] as? String { handleNavigation(url: url) }
        default:
            break
        }
    }
}

// During WKWebView setup:
let controller = WKUserContentController()
controller.add(WebBridge(), name: "native")  // JS: window.webkit.messageHandlers.native
config.userContentController = controller
```

JavaScript side:

```javascript
window.webkit.messageHandlers.native.postMessage({
    action: "resize",
    width: 800,
    height: 600
});
```

### Multiple WKWebViews in a layout

Share a process pool to reduce memory and launch cost:

```swift
final class WebViewManager {
    static let shared = WebViewManager()
    let processPool = WKProcessPool()

    func makeWebView(frame: NSRect) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        return WKWebView(frame: frame, configuration: config)
    }
}
```

Tear down offscreen web views:

```swift
final class CanvasWebTile: NSView {
    private var webView: WKWebView?
    private var snapshot: NSImage?
    private(set) var isActive = false

    func activate() {
        guard !isActive else { return }
        isActive = true
        let wv = WebViewManager.shared.makeWebView(frame: bounds)
        wv.autoresizingMask = [.width, .height]
        addSubview(wv)
        webView = wv
    }

    func deactivate() {
        guard isActive, let wv = webView else { return }
        wv.takeSnapshot(with: nil) { [weak self] image, _ in self?.snapshot = image }
        wv.removeFromSuperview()
        webView = nil
        isActive = false
    }
}
```

### SwiftUI wrapper

```swift
struct WebView: NSViewRepresentable {
    let url: URL
    @Binding var title: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if #available(macOS 13.3, *) {
            // Developer extras are on by default in debug builds on modern macOS
        } else {
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url { webView.load(URLRequest(url: url)) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        init(_ parent: WebView) { self.parent = parent }

        // WKNavigation! uses Apple's implicitly-unwrapped declaration; don't
        // change the signature.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.title = webView.title ?? ""
        }
    }
}
```

### Custom URL schemes

Serve local content via `WKURLSchemeHandler` instead of shipping a tiny bundled HTTP server:

```swift
final class LocalContentHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, url.scheme == "app" else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        let path = url.path
        guard let fileURL = Bundle.main.url(forResource: path, withExtension: nil),
              let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = URLResponse(url: url,
                                   mimeType: mimeTypeForPath(path),
                                   expectedContentLength: data.count,
                                   textEncodingName: nil)
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

// Register during config:
config.setURLSchemeHandler(LocalContentHandler(), forURLScheme: "app")
// Now web content can load: app:///styles.css, app:///script.js, etc.
```

### Keyboard focus

`WKWebView` competes with AppKit for the first responder chain. Route app-level shortcuts before letting the web view eat them:

```swift
final class CompositorView: NSView {
    var activeWebView: WKWebView?

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let tile = tileAt(point), let webView = tile.webView {
            activeWebView = webView
            window?.makeFirstResponder(webView)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for app-level shortcuts first (Cmd+W, Cmd+T, etc.)
        if isAppShortcut(event) { return handleAppShortcut(event) }
        return super.performKeyEquivalent(with: event)
    }
}
```

## Performance considerations

- **Dirty region tracking** — only re-render canvas objects whose content has changed. Cache the rest as offscreen textures.
- **Texture caching for thumbnails** — render each object to an offscreen texture once; invalidate on content change.
- **Batch draw calls** — group by pipeline state; state changes are expensive.
- **Cull first** — skip all rendering work for off-screen objects before building draw calls.
- **LOD crossfade** — blend between LOD levels over a frame or two to avoid popping.
- **Profile before optimizing** — Instruments' Metal template shows exactly where frame time goes; guessing is worse than useless.

## Further reading

- [Metal by Example](https://metalbyexample.com/) — the best narrative tutorial for Metal fundamentals
- [Apple Metal sample code](https://developer.apple.com/metal/sample-code/)
- Ghostty source (`src/renderer/Metal.zig`) — production-grade Metal text renderer in Zig
- For libghostty terminal embedding specifically: `libghostty-integration.md`
