# Metal Rendering Pipeline Reference

## Core Concepts

Metal is Apple's low-level GPU API. It compiles to native machine code — no interpretation layer like WebGL. It's comparable to Vulkan/DirectX 12 in philosophy: explicit command encoding, pre-compiled pipeline states, manual resource synchronization.

### The Rendering Loop

```
1. Get next drawable from CAMetalLayer
2. Create command buffer from command queue
3. Create render pass descriptor (target textures, clear colors)
4. Create render command encoder from pass descriptor
5. Set pipeline state, vertex buffers, textures, uniforms
6. Issue draw calls
7. End encoding
8. Present drawable
9. Commit command buffer
```

## Setting Up Metal in AppKit

### CAMetalLayer vs MTKView

**CAMetalLayer** (recommended for custom apps): Raw Metal surface. You control the display link, frame timing, and resize behavior. Use when building custom renderers, infinite canvases, or embedding Metal in complex view hierarchies.

**MTKView** (convenience wrapper): Subclass of NSView that manages a CAMetalLayer, display link, and resize for you. Good for getting started. Implements `MTKViewDelegate` with `draw(in:)` callback.

### Display Link Setup

```swift
// CVDisplayLink drives the render loop at display refresh rate
private var displayLink: CVDisplayLink?

func setupDisplayLink() {
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
    CVDisplayLinkSetOutputCallback(displayLink!, { (_, _, _, _, _, context) -> CVReturn in
        let view = Unmanaged<MetalCanvasView>.fromOpaque(context!).takeUnretainedValue()
        DispatchQueue.main.async { view.render() }
        return kCVReturnSuccess
    }, Unmanaged.passUnretained(self).toOpaque())
    CVDisplayLinkStart(displayLink!)
}

// Always stop in deinit
deinit {
    if let dl = displayLink {
        CVDisplayLinkStop(dl)
    }
}
```

### Handling Retina / High DPI

```swift
override func layout() {
    super.layout()
    // Convert from points to pixels for Metal
    metalLayer.drawableSize = convertToBacking(bounds).size
}

// Set contentsScale to match screen
metalLayer.contentsScale = window?.backingScaleFactor ?? 2.0
```

## Shader Pipeline

### Metal Shading Language (MSL) Basics

MSL is C++14-based. Shaders go in `.metal` files compiled by Xcode.

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

// Uniforms passed from Swift
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

### Creating a Pipeline State

```swift
func makePipeline() throws -> MTLRenderPipelineState {
    let library = device.makeDefaultLibrary()!
    let vertexFn = library.makeFunction(name: "vertex_main")!
    let fragmentFn = library.makeFunction(name: "fragment_main")!

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFn
    descriptor.fragmentFunction = fragmentFn
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // Vertex descriptor (describes vertex buffer layout)
    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float2   // position
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[1].format = .float4   // color
    vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
    vertexDescriptor.attributes[1].bufferIndex = 0
    vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride + MemoryLayout<SIMD4<Float>>.stride

    descriptor.vertexDescriptor = vertexDescriptor

    return try device.makeRenderPipelineState(descriptor: descriptor)
}
```

### Passing Uniforms

```swift
struct Uniforms {
    var viewProjectionMatrix: float4x4
}

func render() {
    var uniforms = Uniforms(
        viewProjectionMatrix: camera.viewProjectionMatrix
    )

    encoder.setVertexBytes(&uniforms,
                           length: MemoryLayout<Uniforms>.stride,
                           index: 1)
}
```

## Triple Buffering

For smooth rendering, use multiple frame states to avoid CPU/GPU contention:

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

    // Use currentFrameIndex to select per-frame buffers
    let uniformBuffer = uniformBuffers[currentFrameIndex]

    // ... encode commands ...

    commandBuffer.present(drawable)
    commandBuffer.commit()

    currentFrameIndex = (currentFrameIndex + 1) % maxFramesInFlight
}
```

## Offscreen Rendering (for LOD thumbnails)

```swift
func renderToTexture(size: CGSize) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm,
        width: Int(size.width),
        height: Int(size.height),
        mipmapped: false
    )
    descriptor.usage = [.renderTarget, .shaderRead]

    let texture = device.makeTexture(descriptor: descriptor)!

    let passDescriptor = MTLRenderPassDescriptor()
    passDescriptor.colorAttachments[0].texture = texture
    passDescriptor.colorAttachments[0].loadAction = .clear
    passDescriptor.colorAttachments[0].storeAction = .store

    // Encode draw calls targeting this texture instead of the screen
    // The resulting texture can be displayed as a textured quad in the main pass

    return texture
}
```

## Alpha Blending (for overlays, connections)

```swift
// Enable alpha blending on the pipeline
descriptor.colorAttachments[0].isBlendingEnabled = true
descriptor.colorAttachments[0].rgbBlendOperation = .add
descriptor.colorAttachments[0].alphaBlendOperation = .add
descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
```

## Text Rendering Approaches

1. **Texture atlas** (Ghostty's approach): Rasterize glyphs to a texture atlas on CPU, sample in fragment shader. Fast, but fixed resolution — can look blurry at non-native zoom levels.

2. **MSDF (Multi-channel Signed Distance Fields)**: Resolution-independent text. Sharp at any zoom level. Ideal for infinite canvas where zoom varies. More complex setup but superior quality for zoomable UIs. See try! Swift Tokyo 2025 talk.

3. **Core Text + offscreen render**: Render text to CGContext, upload as texture. Simple but CPU-bound and doesn't scale to many text elements.
