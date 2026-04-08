# Infinite Canvas Architecture

## Overview

An infinite canvas is a viewport (camera) looking into an unbounded 2D coordinate space. Objects exist in world-space coordinates. The camera transform converts world → screen coordinates. Pan = translate camera. Zoom = scale camera.

## Camera System

```swift
struct Camera {
    var position: SIMD2<Float> = .zero  // World-space center
    var zoom: Float = 1.0               // Scale factor
    var screenSize: SIMD2<Float> = .zero // Viewport size in pixels

    // World → Screen transform (pass to GPU as uniform)
    var viewMatrix: float4x4 {
        let scale = float4x4(scaleBy: SIMD3(zoom, zoom, 1))
        let translate = float4x4(translationBy: SIMD3(
            -position.x * zoom + screenSize.x / 2,
            -position.y * zoom + screenSize.y / 2,
            0
        ))
        return translate * scale
    }

    // Screen → World (for hit testing, placing objects)
    func screenToWorld(_ screenPoint: CGPoint) -> SIMD2<Float> {
        let x = (Float(screenPoint.x) - screenSize.x / 2) / zoom + position.x
        let y = (Float(screenPoint.y) - screenSize.y / 2) / zoom + position.y
        return SIMD2(x, y)
    }

    // Visible world-space bounds (for frustum culling)
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

## Gesture Handling (AppKit)

```swift
class CanvasView: NSView {
    var camera = Camera()
    private var lastPanLocation: CGPoint?
    private var lastMagnification: CGFloat = 1.0

    override func magnify(with event: NSEvent) {
        // Pinch to zoom — zoom toward cursor position
        let cursorWorld = camera.screenToWorld(
            convert(event.locationInWindow, from: nil)
        )
        let oldZoom = camera.zoom
        camera.zoom *= Float(1.0 + event.magnification)
        camera.zoom = max(0.1, min(camera.zoom, 10.0))  // Clamp

        // Adjust position to zoom toward cursor
        let zoomRatio = camera.zoom / oldZoom
        camera.position.x = cursorWorld.x + (camera.position.x - cursorWorld.x) / zoomRatio
        camera.position.y = cursorWorld.y + (camera.position.y - cursorWorld.y) / zoomRatio
    }

    override func scrollWheel(with event: NSEvent) {
        // Two-finger scroll to pan
        camera.position.x -= Float(event.scrollingDeltaX) / camera.zoom
        camera.position.y -= Float(event.scrollingDeltaY) / camera.zoom
    }

    override func mouseDown(with event: NSEvent) {
        let worldPoint = camera.screenToWorld(
            convert(event.locationInWindow, from: nil)
        )
        // Hit test against canvas objects at worldPoint
    }
}
```

## Canvas Object Model

```swift
protocol CanvasObject: AnyObject {
    var id: UUID { get }
    var worldPosition: SIMD2<Float> { get set }
    var worldSize: SIMD2<Float> { get }
    var zIndex: Int { get }

    func render(encoder: MTLRenderCommandEncoder, camera: Camera, lod: LODLevel)
}

enum LODLevel {
    case full        // Close zoom — full fidelity rendering
    case thumbnail   // Medium zoom — cached texture
    case placeholder // Far zoom — colored rectangle
}

class CanvasState {
    var objects: [UUID: CanvasObject] = [:]
    var connections: [Connection] = []
    var camera = Camera()
    var spatialIndex = SpatialHash<CanvasObject>(cellSize: 500)

    func visibleObjects() -> [CanvasObject] {
        let visible = spatialIndex.query(rect: camera.visibleRect)
        return visible.sorted { $0.zIndex < $1.zIndex }
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

## Spatial Hash (for frustum culling)

```swift
class SpatialHash<T: CanvasObject> {
    let cellSize: Float
    private var cells: [SIMD2<Int32>: [T]] = [:]

    init(cellSize: Float) {
        self.cellSize = cellSize
    }

    private func cellKey(for point: SIMD2<Float>) -> SIMD2<Int32> {
        SIMD2(Int32(floor(point.x / cellSize)),
              Int32(floor(point.y / cellSize)))
    }

    func insert(_ object: T) {
        let minKey = cellKey(for: object.worldPosition)
        let maxKey = cellKey(for: object.worldPosition + object.worldSize)
        for x in minKey.x...maxKey.x {
            for y in minKey.y...maxKey.y {
                let key = SIMD2(x, y)
                cells[key, default: []].append(object)
            }
        }
    }

    func query(rect: CGRect) -> [T] {
        let minKey = cellKey(for: SIMD2(Float(rect.minX), Float(rect.minY)))
        let maxKey = cellKey(for: SIMD2(Float(rect.maxX), Float(rect.maxY)))
        var result: Set<ObjectIdentifier> = []
        var objects: [T] = []
        for x in minKey.x...maxKey.x {
            for y in minKey.y...maxKey.y {
                for obj in cells[SIMD2(x, y)] ?? [] {
                    if result.insert(ObjectIdentifier(obj)).inserted {
                        objects.append(obj)
                    }
                }
            }
        }
        return objects
    }

    func clear() { cells.removeAll() }
}
```

## Connection Rendering

Connections between objects (e.g., terminal pipes) render as curves:

```swift
struct Connection {
    let sourceId: UUID
    let targetId: UUID
    let dataFlow: DataFlowDirection  // .unidirectional, .bidirectional

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

Render curves either via:
1. **GPU tessellation**: Convert Bézier to line segments in vertex shader, draw as triangle strip with width
2. **Core Graphics overlay**: Draw curves in a separate `NSView` layer above the Metal canvas (simpler, lower performance)
3. **Instanced line rendering**: Pre-tessellate on CPU, upload as vertex buffer

## Render Loop

```swift
func render() {
    let visible = canvasState.visibleObjects()

    guard let drawable = metalLayer.nextDrawable(),
          let commandBuffer = commandQueue.makeCommandBuffer() else { return }

    let passDescriptor = MTLRenderPassDescriptor()
    passDescriptor.colorAttachments[0].texture = drawable.texture
    passDescriptor.colorAttachments[0].loadAction = .clear
    passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
    passDescriptor.colorAttachments[0].storeAction = .store

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

    // Pass 1: Object backgrounds
    for object in visible {
        let lod = canvasState.lodLevel(for: object)
        object.render(encoder: encoder, camera: canvasState.camera, lod: lod)
    }

    // Pass 2: Connections
    for connection in canvasState.connections {
        renderConnection(connection, encoder: encoder)
    }

    // Pass 3: Selection/UI overlay
    renderSelectionHandles(encoder: encoder)

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
}
```

## Performance Considerations

- **Dirty region tracking**: Only re-render terminals whose content has changed. Cache others as textures.
- **Texture caching for thumbnails**: When zoomed out, render each terminal to an offscreen texture once, reuse until content changes.
- **Batched draw calls**: Group objects by pipeline state to minimize state changes.
- **Frustum culling first**: Skip all rendering work for off-screen objects.
- **LOD transitions**: Smooth crossfade between LOD levels to avoid popping.
