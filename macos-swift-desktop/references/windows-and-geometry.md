# Windows and Geometry

This reference covers `NSWindow` and `NSWindowController` lifecycle, programmatic window creation, frame autosave, multi-screen arithmetic, fullscreen and collection behavior, borderless/transparent windows, state restoration, and the panels/HUD variants. The focus is on AppKit-side window management; SwiftUI `WindowGroup` and `Window` scenes are mentioned only where they bridge to AppKit behavior.

## Table of contents

- [NSWindowController vs direct NSWindow](#nswindowcontroller-vs-direct-nswindow)
- [Creating a programmatic window](#creating-a-programmatic-window)
- [Frame auto-save](#frame-auto-save)
- [Multi-screen basics](#multi-screen-basics)
- [Placing a window on a specific screen](#placing-a-window-on-a-specific-screen)
- [Multi-screen arithmetic pitfalls](#multi-screen-arithmetic-pitfalls)
- [Fullscreen](#fullscreen)
- [Collection behavior](#collection-behavior)
- [Borderless and transparent windows](#borderless-and-transparent-windows)
- [Window state restoration](#window-state-restoration)
- [Multiple windows per scene](#multiple-windows-per-scene)
- [Panels and HUDs](#panels-and-huds)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## NSWindowController vs direct NSWindow

Subclass `NSWindowController` and let it own the `NSWindow`. The controller handles `showWindow(_:)`, `close()`, window-level notifications (`windowDidBecomeKey`, `windowWillClose`), and plugs into `NSDocument` for document-based apps. Raw `NSWindow` works for quick prototypes but skips restoration hooks and gives you nowhere clean to hang window-scoped state.

```swift
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    convenience init(viewModel: MainViewModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: MainContentView(viewModel: viewModel))
        window.title = viewModel.title
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.setFrameAutosaveName("MainWindow")
    }
}
```

Call `showWindow(nil)` to display, `close()` to dismiss. The controller stays alive as long as something retains it — typically the app delegate or an `NSDocument`.

## Creating a programmatic window

```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
window.title = "My App"
window.center()
window.isReleasedWhenClosed = false  // Mandatory when window is owned by a controller
```

Style mask flags:

| Flag | Effect |
| --- | --- |
| `.titled` | Shows the title bar. Without it, the window is borderless. |
| `.closable` | Red traffic light and `Cmd+W`. |
| `.miniaturizable` | Yellow traffic light (minimize to dock). |
| `.resizable` | Resizing and the green zoom button. |
| `.fullSizeContentView` | Content view extends under the title bar. Pair with `titlebarAppearsTransparent = true`. |
| `.borderless` | No chrome. Mutually exclusive with `.titled`. |
| `.utilityWindow` | Thin title bar, floats above regular windows. `NSPanel` only. |
| `.hudWindow` | Dark translucent HUD. `NSPanel` only. |

`isReleasedWhenClosed` defaults to `true` (pre-ARC behavior). Combined with ARC plus an `NSWindowController` retaining the window, that double-free crashes. **Always set it to `false` for controller-owned windows.** SwiftUI-hosted windows already default to `false`.

## Frame auto-save

```swift
window.setFrameAutosaveName("MainWindow")
```

Persists the window's frame to `UserDefaults` under `NSWindow Frame <name>`. Next launch restores it — no manual serialization. The name must be unique per window; reusing one causes windows to stomp each other.

SwiftUI `WindowGroup` sets an autosave name implicitly from the scene identifier. AppKit windows must set it manually. Clear a stale frame with `NSWindow.removeFrame(usingName:)`.

## Multi-screen basics

```swift
// All connected screens; NSScreen.main is the one with the key window right now
let screens = NSScreen.screens
let menuBarScreen = NSScreen.main  // Optional — may be nil at launch before any window is key

// `frame` is the full bounds; `visibleFrame` excludes menu bar and dock
let full = NSScreen.main?.frame ?? .zero
let usable = NSScreen.main?.visibleFrame ?? .zero
```

macOS windows use a **bottom-left origin** coordinate system — Y grows upward, opposite to iOS/SwiftUI. A window at `(0, 0)` with height 600 has its top edge at `y = 600`. Porting top-left math from iOS places windows off-screen or upside-down.

`frame` is the screen's full bounds. `visibleFrame` subtracts the menu bar and dock. For "place this window somewhere the user can actually see it" logic, always use `visibleFrame`.

## Placing a window on a specific screen

```swift
func place(_ window: NSWindow, on screen: NSScreen, size: NSSize) {
    let visible = screen.visibleFrame
    // Center within the target screen's visible area (not its full frame, so we
    // don't hide the title bar behind the menu bar)
    let origin = NSPoint(
        x: visible.midX - size.width / 2,
        y: visible.midY - size.height / 2
    )
    window.setFrame(NSRect(origin: origin, size: size), display: true)
}

// Usage
if let secondary = NSScreen.screens.dropFirst().first {
    place(window, on: secondary, size: NSSize(width: 800, height: 500))
}
```

`setFrame(_:display:)` takes global screen coordinates (a union of all connected screens). `visibleFrame` is already in global space — no per-screen conversion needed.

## Multi-screen arithmetic pitfalls

- **Screens can be at negative coordinates.** A secondary display positioned to the left of the main has negative `frame.origin.x`. Never assume `(0, 0)`.
- **Backing scale factor differs per screen.** A Retina MacBook with a non-Retina external has `backingScaleFactor` 2.0 and 1.0. Metal layers need `drawableSize` recomputed when a window moves between screens — observe `NSWindow.didChangeBackingPropertiesNotification`.
- **The menu bar can be on any screen** depending on the user's "Displays have separate Spaces" setting. `NSScreen.main` is not the menu-bar screen — prefer explicit per-window logic.
- **`NSScreen.main` is not stable.** It returns the screen containing the key window *at the moment of the call*. Cache it and you get stale results when the user drags to another display. Call fresh, or observe `NSApplication.didChangeScreenParametersNotification`.

## Fullscreen

```swift
window.collectionBehavior.insert(.fullScreenPrimary)
window.toggleFullScreen(nil)
```

Two distinct fullscreen modes:

- **Native fullscreen** — window gets its own Space. Triggered by the green button, `toggleFullScreen(_:)`, or `Cmd+Ctrl+F`. Requires `.fullScreenPrimary` in `collectionBehavior`.
- **Zoomed windowed** — green button press-and-hold, "Zoom". Grows the window to `visibleFrame` without changing Spaces. Triggered via `window.zoom(_:)` or the user.

Native fullscreen breaks overlay behavior: floating panels, inspectors, and HUDs do not appear above a fullscreen window unless they have `.canJoinAllSpaces` or `.fullScreenAuxiliary` set. Mark document tool windows as `.fullScreenAuxiliary` so they enter the document's fullscreen Space.

Observe entry/exit via `NSWindow.willEnterFullScreenNotification` and `NSWindow.didExitFullScreenNotification`.

## Collection behavior

`NSWindow.CollectionBehavior` controls how a window interacts with Mission Control, Spaces, and fullscreen:

| Flag | Effect |
| --- | --- |
| `.canJoinAllSpaces` | Window appears on every Space. Menu-bar apps, global overlays. |
| `.moveToActiveSpace` | Window follows the user when they switch Spaces. |
| `.stationary` | Window stays in its current Space when the user switches. |
| `.fullScreenPrimary` | Window can enter native fullscreen on its own. |
| `.fullScreenAuxiliary` | Window can join another window's fullscreen Space (inspectors, palettes). |
| `.fullScreenNone` | Window is excluded from fullscreen entirely. |
| `.participatesInCycle` | Window takes part in `Cmd+~` window cycling. |
| `.ignoresCycle` | Window is skipped by `Cmd+~`. |

```swift
// Always-on-top overlay that follows the user between Spaces
overlay.level = .floating
overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

// Inspector that joins its document's fullscreen Space
inspector.collectionBehavior = [.fullScreenAuxiliary]
```

Flags combine via `insert`, `remove`, or a set literal. `.stationary` and `.moveToActiveSpace` are mutually exclusive; same for `.participatesInCycle` and `.ignoresCycle`.

## Borderless and transparent windows

For HUDs, on-screen drawing surfaces, and custom-chromed windows:

```swift
@MainActor
final class OverlayWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    // Borderless windows return false by default. Override so the window can
    // become key and receive keyboard input.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

Borderless windows refuse to become key by default — no keyboard input, no text field focus, no `performKeyEquivalent`. Override `canBecomeKey` on an `NSWindow` subclass if you need input. Set `ignoresMouseEvents = true` for click-through visual-only overlays.

## Window state restoration

State restoration preserves open windows, scroll position, and view state across launches and relaunches.

```swift
window.isRestorable = true
window.restorationClass = MainWindowController.self
```

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true  // Required on macOS 12+ to opt into secure coding
    }
}
```

SwiftUI handles restoration automatically for `WindowGroup` and `Settings` scenes. AppKit windows need explicit `NSWindowRestoration` conformance on the restoration class, plus encode/decode of per-window state via `NSCoder`. See `app-lifecycle.md` for the full wiring and secure-coding requirements.

## Multiple windows per scene

AppKit: one `NSWindowController` instance per window. For document-based apps, `NSDocument` owns its controllers via `makeWindowControllers()` and adds them with `addWindowController(_:)`. `NSWindowController` instances are retained by the document (or the app delegate), so a controller stays alive as long as its window is open.

SwiftUI:

- `WindowGroup { ... }` — creates one window per user-created instance (File > New Window, or opened document). You cannot reliably address individual windows by identifier, and you cannot mutate per-window state from outside the window.
- `Window(id:) { ... }` — exactly one window with a stable identifier. Supports `openWindow(id:)` and `dismissWindow(id:)` from the `@Environment`. Use this for singleton windows like "About" or "Inspector".
- `UtilityWindow(id:) { ... }` — on macOS 15+, a singleton utility window (thin title bar, floats above main windows).

For any app that needs more than "user opens N copies of the same view", drop to AppKit `NSWindowController`. SwiftUI's `WindowGroup` does not expose enough of the per-window lifecycle to manage window state from a coordinator.

## Panels and HUDs

`NSPanel` is an `NSWindow` subclass with floating-above-main-windows behavior and thinner chrome. Use it for inspectors, palettes, utility windows, and HUDs.

```swift
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 240, height: 360),
    styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.title = "Inspector"
panel.isFloatingPanel = true
panel.becomesKeyOnlyIfNeeded = true
panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
panel.hidesOnDeactivate = true
```

Panel-specific style masks: `.utilityWindow` (thin title bar, translucent — tool palettes), `.hudWindow` (dark translucent HUD — pair with `.nonactivatingPanel`), `.nonactivatingPanel` (clicking doesn't activate the app — essential for floating palettes that shouldn't yank focus). `isFloatingPanel = true` keeps the panel above normal windows within the app. `hidesOnDeactivate = true` hides it when the app loses focus.

## Common pitfalls

- **Forgetting `isReleasedWhenClosed = false`** on controller-owned windows — double-free crash on close under ARC.
- **Computing window positions in screen 0 coordinates** when the user has multiple screens. Always use `visibleFrame` from the target `NSScreen` and write in global screen space.
- **Setting `window.contentView` after `showWindow`** without triggering relayout. Use `contentViewController` or call `window.layoutIfNeeded()` after swapping.
- **Assuming `NSScreen.main` is stable** across calls. It changes with focus; call it fresh each time.
- **Using iOS-style top-left origin math** on `NSWindow` frames. `window.frame.origin.y` is the bottom edge, not the top.
- **Skipping `.fullScreenAuxiliary` on inspector panels** — they vanish when the main document enters native fullscreen.
- **Reusing a frame autosave name** across multiple windows — each window stomps the others' persisted frame.
- **Borderless windows that never receive keyboard input** — override `canBecomeKey` and `canBecomeMain`.

## References

- **Rectangle** (`/WindowManager/`) — production-grade window-geometry math, multi-screen arithmetic, `visibleFrame` handling, Mission Control integration. The canonical reference for anything screen-layout related.
- **CodeEdit** (`CodeEditWindowController.swift`) — modern `NSWindowController` subclass with SwiftUI content via `NSHostingController`, toolbar integration, and document linkage.
- `references/app-lifecycle.md` — window state restoration wiring, `applicationSupportsSecureRestorableState`, secure-coding requirements.
- `references/appkit-swiftui-hybrid.md` — `NSHostingController` as the content view of an AppKit window; the preferred shape for hybrid apps.
- `references/menu-bar-apps.md` — `NSStatusItem` and `LSUIElement` for menu-bar-only apps (`.canJoinAllSpaces` conventions live there).
- `references/document-apps.md` — `NSDocument.makeWindowControllers()` and multi-window document patterns.
