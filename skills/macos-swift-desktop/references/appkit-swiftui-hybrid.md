# AppKit + SwiftUI Hybrid Architecture

This reference covers how to structure a macOS desktop app that uses AppKit for the outer shell (windows, menus, toolbars, documents) and SwiftUI for inner content panels. It explains the bridging APIs (`NSHostingView`, `NSHostingController`, `NSViewRepresentable`), the Coordinator pattern, the lifecycle pitfalls you will hit, and rules of thumb for which framework to reach for first.

## Table of contents

- [Why hybrid?](#why-hybrid)
- [The decision matrix](#the-decision-matrix)
- [The structural rule](#the-structural-rule)
- [Bridging SwiftUI into AppKit](#bridging-swiftui-into-appkit)
- [Bridging AppKit into SwiftUI](#bridging-appkit-into-swiftui)
- [The Coordinator pattern in depth](#the-coordinator-pattern-in-depth)
- [Lifecycle pitfalls](#lifecycle-pitfalls)
- [When to default to AppKit](#when-to-default-to-appkit)
- [When to default to SwiftUI](#when-to-default-to-swiftui)
- [References](#references)

## Why hybrid?

- **AppKit gives you** the mature desktop primitives: `NSWindow`, `NSWindowController`, `NSToolbar`, `NSSplitViewController`, `NSMenu`, `NSResponder` chain, `NSDocument`, drag sessions, pasteboard, Touch Bar, and full control over first responder, key equivalents, and menu validation.
- **SwiftUI gives you** declarative layout for forms, sidebars, inspectors, and settings — the kinds of panels where AppKit's target-action code is tedious and repetitive. It composes well, animates for free, and handles dynamic type and dark mode.
- **Pure SwiftUI on macOS** is missing or flaky for: multi-window coordination (`WindowGroup` can't cleanly address individual windows), borderless/transparent windows, custom window chrome, system tray / menu bar apps, fine-grained focus chain control, and per-menu validation.
- **Pure SwiftUI also falls short** on custom rendering surfaces: hosting a `CAMetalLayer`, a text editor with its own layout manager, or any view that needs to override `NSResponder` methods directly.
- **Pure AppKit** works everywhere but is verbose for anything form-shaped. Writing a preferences window in AppKit in 2026 is busywork.
- **The hybrid split** lets each framework do what it's good at: AppKit owns the structural shell, SwiftUI owns the content panels, custom `NSView` subclasses handle performance-critical surfaces.

## The decision matrix

| If you need...                                                 | Use                                                                        |
| ---                                                            | ---                                                                        |
| App lifecycle, `@main`, delegate callbacks                     | AppKit (`NSApplicationDelegate`)                                           |
| Main menu, menu validation, key equivalents                    | AppKit (`NSMenu`, `validateMenuItem(_:)`)                                  |
| Window management, multi-window coordination, frame restoration | AppKit (`NSWindowController`, `NSWindow`)                                |
| Document model, autosave, versions, file coordination          | AppKit (`NSDocument`, `NSDocumentController`)                              |
| Toolbar                                                        | AppKit (`NSToolbar`) — both work; AppKit is more reliable and customizable |
| Split view with sidebar, content, inspector                    | AppKit shell (`NSSplitViewController`) hosting SwiftUI panes               |
| Sidebar / inspector / settings forms                           | SwiftUI                                                                    |
| Settings window for a simple app                               | SwiftUI `Settings { }` scene                                               |
| Custom rendering (Metal, text editor, canvas)                  | Custom `NSView` subclass, wrapped via `NSViewRepresentable` when needed    |
| Menu bar / status item app                                     | AppKit (`NSStatusItem`) — see `menu-bar-apps.md`                           |
| Borderless or transparent window, custom window chrome         | AppKit (`NSWindow` subclass with `styleMask`)                              |
| Tab-based content switcher inside one window                   | SwiftUI (`TabView`) or AppKit (`NSTabViewController`)                      |
| Drag-and-drop across windows, custom pasteboard types          | AppKit                                                                     |

The table is a starting point, not a law. When a row pulls both ways, prefer AppKit for the outer container and SwiftUI for the leaves.

## The structural rule

AppKit owns the outer shell. SwiftUI owns content panels. Custom `NSView` subclasses live inside those panels when you need performance or responder-chain control.

See the diagram in `SKILL.md` under "Mental model: AppKit + SwiftUI hybrid". The invariant is: **you can always drop from SwiftUI down to a custom `NSView`, but you cannot cleanly push a SwiftUI view *above* the `NSWindow` boundary.** Start at the top in AppKit and insert SwiftUI where it earns its keep.

## Bridging SwiftUI into AppKit

`NSHostingView` wraps a SwiftUI view as an `NSView`. `NSHostingController` wraps a SwiftUI view as an `NSViewController`. For anything that participates in the AppKit view-controller hierarchy (split view items, tab view items, window content), prefer `NSHostingController` — it plugs into the responder chain correctly and forwards lifecycle callbacks.

```swift
import AppKit
import SwiftUI

final class MainWindowController: NSWindowController {
    convenience init(viewModel: DocumentViewModel) {
        // SwiftUI root for the content pane. The window chrome — toolbar, title
        // bar, traffic lights — stays in AppKit so menu validation and window
        // restoration behave like every other Mac app.
        let rootView = DocumentContentView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 900, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = viewModel.title
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }
}
```

This is the **preferred direction** for hybrid apps: AppKit on the outside, SwiftUI on the inside. The content view gets declarative layout, `@Environment`, previews, and cheap state-driven updates; the window gets everything AppKit users expect.

A few practical notes on the bridge:

- `NSHostingController` forwards `viewDidLoad`, `viewWillAppear`, `viewDidAppear`, `viewWillDisappear`, and `viewDidDisappear` — subclass it when you need lifecycle hooks SwiftUI doesn't expose (e.g. to attach an `NSToolbar` once the window exists).
- Inject dependencies into the SwiftUI root view via its initializer (preferred) or `.environment(_:_:)` — do **not** rely on global singletons, because previews and tests will not see them.
- Set `sizingOptions` on the hosting controller if you want the window to resize to the SwiftUI content's intrinsic size; otherwise the window keeps the frame you set in AppKit and SwiftUI lays out inside it.

## Bridging AppKit into SwiftUI

When you have to expose a custom `NSView` to a SwiftUI tree (because the surrounding layout is already SwiftUI, or because you are embedding a bespoke rendering surface), conform to `NSViewRepresentable`.

```swift
import AppKit
import SwiftUI

struct RulerView: NSViewRepresentable {
    @Binding var unit: RulerUnit
    var onTickHover: (CGFloat) -> Void

    func makeNSView(context: Context) -> CustomRulerNSView {
        // makeNSView runs ONCE per representable instance. Do expensive setup
        // here, not in updateNSView.
        let view = CustomRulerNSView()
        view.delegate = context.coordinator
        view.unit = unit
        return view
    }

    func updateNSView(_ nsView: CustomRulerNSView, context: Context) {
        // Called on every SwiftUI re-render. Diff before mutating so we don't
        // trigger needless redraws or reset internal state.
        if nsView.unit != unit {
            nsView.unit = unit
        }
        context.coordinator.onTickHover = onTickHover
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTickHover: onTickHover)
    }
}
```

The representable itself is a value type, recreated cheaply on every SwiftUI invalidation. The `NSView` it wraps lives across re-renders; SwiftUI manages its lifetime. The `Coordinator` is how you bridge delegate callbacks back into SwiftUI state.

Think of the three entry points as:

- `makeNSView(context:)` — construct the view, wire delegates to `context.coordinator`, install initial state. Runs once.
- `updateNSView(_:context:)` — SwiftUI state changed; push the diff into the NSView. Runs often. Must be idempotent.
- `makeCoordinator()` — construct the Coordinator. Runs once.

## The Coordinator pattern in depth

A `Coordinator` holds mutable state and delegate conformances that the value-type representable cannot. Mark it `@MainActor` — AppKit views only call their delegates on the main thread, and Coordinator state is UI state.

```swift
extension RulerView {
    @MainActor
    final class Coordinator: NSObject, CustomRulerDelegate {
        var onTickHover: (CGFloat) -> Void

        init(onTickHover: @escaping (CGFloat) -> Void) {
            self.onTickHover = onTickHover
        }

        // Delegate callback from the NSView. We surface it to SwiftUI via the
        // closure, which was captured from the current representable snapshot
        // inside updateNSView — not the initial one.
        func rulerView(_ view: CustomRulerNSView, didHoverAt position: CGFloat) {
            onTickHover(position)
        }
    }
}
```

Rules for Coordinators:

- **Re-bind closures in `updateNSView`**, not `makeCoordinator`. The closures captured at `makeCoordinator` time see stale SwiftUI state; the ones assigned in `updateNSView` see the current values.
- **Store `Binding`s, not raw values.** A `Binding<T>` is how you write back into SwiftUI state from a delegate method; copying the current value buys you nothing.
- **Never retain `self` from inside closures that the NSView stores long-term.** Capture `weak self` or split the closure so the Coordinator owns the NSView, not the other way around.

## Lifecycle pitfalls

- **`makeNSView` returning a `CAMetalLayer`-backed view with zero bounds.** SwiftUI hasn't performed layout yet when `makeNSView` runs, so `bounds` is `.zero`. If you set `drawableSize` from `bounds` at construction you get a 1x1 render target. Defer drawable-size setup to `layout()` or `viewDidMoveToWindow()`, never in `makeNSView`. See `advanced-rendering.md` for the full Metal-in-AppKit pattern.
- **`updateNSView` running on every SwiftUI re-render.** It can fire dozens of times per second. Keep it idempotent and cheap: diff before mutating, never allocate inside it, and never create new Coordinator-owned state from it.
- **Coordinators capturing `self` strongly in closures.** A Coordinator that hands out `{ [unowned view] in view.doSomething() }` is fine; one that captures `self` in a closure the NSView stores forever is a retain cycle waiting for the first leak test. Use `weak` or `unowned` deliberately.
- **`NSHostingView` embedded in AppKit with no frame.** SwiftUI needs an intrinsic size or an explicit frame to lay out. If you add a hosting view as a subview and forget to set `frame` or install Auto Layout constraints, you get an invisible view with zero bounds. Either give it a frame, or set `translatesAutoresizingMaskIntoConstraints = false` and pin it.
- **Animating into a hosting view from AppKit.** Core Animation animations on the hosting view's layer do not cross into SwiftUI's render graph. Animate inside SwiftUI with `withAnimation`, or animate the AppKit container (position, alpha) and let SwiftUI redraw at the new size.
- **First responder handoff.** A `NSHostingController` participates in the responder chain, but SwiftUI's focus model (`@FocusState`) is separate from AppKit's `firstResponder`. When mixing, expect to route key equivalents explicitly through `performKeyEquivalent(with:)` on the hosting view's parent.
- **Stale `@Environment` after window reparenting.** Moving a hosting controller between windows can lose environment values that depend on window traits. Re-inject via `.environment(\.window, ...)` after the move, or own the environment values in an `Observable` model outside the hosting controller.

## When to default to AppKit

Reach for AppKit first — without even trying SwiftUI — when any of the following are true:

- Custom window chrome: borderless, transparent, non-rectangular, or traffic-light repositioning
- Menu bar / status item app (`LSUIElement`, `NSStatusItem`) — see `menu-bar-apps.md`
- Multi-document app with inter-document communication or shared state
- Drag-and-drop that crosses window boundaries or uses custom pasteboard types
- Touch Bar support
- Accessibility-critical UI where you need `NSAccessibilityElement` subclassing or custom `accessibilityChildren`
- Any view that needs to override `NSResponder` methods: `keyDown`, `flagsChanged`, `performKeyEquivalent`, `mouseDown` with event routing
- Complex menu validation with per-menu-item state that depends on first responder
- Frame autosave / state restoration across launches

In these cases the cost of fighting SwiftUI's model exceeds the cost of writing the AppKit version. Write the AppKit shell and, if needed, drop SwiftUI inside the content area later.

## When to default to SwiftUI

SwiftUI is the right default when **all** of the following hold:

- Single window or a small fixed number of windows
- No document model, or a trivial one (`FileDocument` is fine for read-only viewers)
- The app is a settings / inspector / sidebar-heavy tool with mostly forms
- No custom window chrome, no menu bar app, no multi-display coordination
- Internal tools and prototypes where shipping speed matters more than desktop polish
- Tab-based content panels where a `TabView` or `NavigationSplitView` covers the layout

The `Settings { }` scene is a particularly good SwiftUI sweet spot — it pairs with any AppKit app as a SwiftUI preferences window without forcing the whole app into SwiftUI.

## References

- `references/reference-repos.md` — **CodeEdit** and **Xcodes.app** are the canonical hybrid examples in the tier-1 list. Both use `NSSplitViewController` shells with SwiftUI panels and custom `NSView` content.
- `references/advanced-rendering.md` — for custom `NSView` subclasses that host Metal, infinite canvases, or `WKWebView`.
- `references/menu-bar-apps.md` — for `NSStatusItem` apps; the hybrid rules there tilt even further toward AppKit.
- Apple developer documentation — search for "Embracing SwiftUI on macOS", "NSHostingView", "NSHostingController", and "NSViewRepresentable"; verify signatures against the current SDK rather than trusting any example here.
- WWDC — search for sessions on AppKit and SwiftUI interop; Apple has published multiple, and the specific session numbers change year to year.
