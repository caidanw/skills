# Menu Bar Apps: NSStatusItem, LSUIElement, Activation Policy

This reference covers building macOS apps whose primary UI is an icon in the system menu bar — status items, activation policies, click handling, `MenuBarExtra`, launch-at-login, and the pitfalls that make a status item disappear or hang the menu bar for every other app on the system. Use this doc when your app has no dock presence or when its main window is secondary to a menu-bar control.

## Table of contents

- [What "menu bar app" means](#what-menu-bar-app-means)
- [Hiding the dock icon](#hiding-the-dock-icon)
- [Creating an NSStatusItem](#creating-an-nsstatusitem)
- [Two modes: menu vs popover](#two-modes-menu-vs-popover)
- [Hybrid click behavior](#hybrid-click-behavior)
- [SwiftUI MenuBarExtra](#swiftui-menubarextra)
- [Icons and templates](#icons-and-templates)
- [Global keyboard shortcut](#global-keyboard-shortcut)
- [Launch at login](#launch-at-login)
- [Hiding from Cmd+Tab](#hiding-from-cmdtab)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## What "menu bar app" means

A **menu bar app** is an app whose primary UI is an `NSStatusItem` in the system menu bar (top-right of the screen, next to Wi-Fi and Control Center). It usually has no main window and no dock icon; clicking the status item reveals a menu, popover, or small panel. Examples: Rectangle, Ice, Stats, Bartender, Caffeine, Tailscale, 1Password Mini.

Menu bar apps are still regular `.app` bundles with full entitlements, sandbox, and code signing — they are not launch daemons. What distinguishes them is the activation policy and the absence of a main window scene.

## Hiding the dock icon

There are three ways to keep your app out of the dock. Pick one based on whether you ever need a dock icon:

| Method | When | Notes |
| --- | --- | --- |
| `LSUIElement = true` in `Info.plist` | Always hidden | Standard pattern; app starts with no dock icon, no main menu, no Cmd+Tab entry |
| `NSApp.setActivationPolicy(.accessory)` at runtime | Toggle dynamically | For apps that can switch between menu-bar mode and regular mode (e.g. showing a settings window in the dock) |
| `NSApp.setActivationPolicy(.prohibited)` | Very rare | Background daemon — no UI at all, not even a status item. Almost never what you want |

Use `LSUIElement = true` for permanent menu-bar apps. Use `.accessory` for apps that toggle — e.g. a video capture app that lives in the menu bar but pops out a full window during recording. `.prohibited` is for background tools without any visible UI; prefer an actual agent target if that is what you need. Both `LSUIElement` and `.accessory` suppress the main menu bar (Apple menu, app name, File, Edit, ...) but still allow windows, sheets, and alerts.

## Creating an NSStatusItem

The canonical pattern is a `StatusBarController` owned by the `NSApplicationDelegate`. The controller retains the status item for the lifetime of the app.

```swift
import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu: NSMenu

    init() {
        // variableLength lets the icon size itself; use a fixed length only
        // when you need pixel-perfect alignment with another status item.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.target == nil { item.target = self }

        if let button = statusItem.button {
            // SF Symbols adapt to the menu bar height and dark mode automatically.
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "My App")
            button.image?.isTemplate = true
            button.action = #selector(handleClick(_:))
            button.target = self
            // sendAction on both mouse-down events so we can distinguish left vs right.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil  // reset so left-click doesn't also auto-show
        } else {
            togglePopover()
        }
    }

    @objc private func openSettings() { /* ... */ }
    private func togglePopover() { /* ... */ }
}
```

`NSStatusBar` does not retain the item on your behalf — store the controller as a strong property on the app delegate:

```swift
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
    }
}
```

## Two modes: menu vs popover

Status items show either an `NSMenu` or an `NSPopover` when clicked. Pick the mode based on content:

- **`NSMenu`** — simple list of actions, toggles, submenus, or recent items. Feels native, auto-dismisses on outside click, respects the global menu animation, and participates in the accessibility hierarchy correctly. **This is the right default.**
- **`NSPopover`** — a mini-window attached to the status item for rich custom UI (forms, charts, a search field). Use only when a menu genuinely cannot express what you need. **Popovers have known pitfalls:** dismissal is unreliable when the user clicks outside your app process, the animation does not match `NSMenu`, and they do not interact well with Mission Control or Stage Manager. See `anti-patterns.md`.

### Attaching an NSMenu

The simplest case: assign a menu and let the status item handle clicks. No action method, no target, no click routing.

```swift
statusItem.menu = menu  // click auto-shows the menu and dismisses correctly
```

If you set `statusItem.menu`, the button's `action` and `target` are ignored. You lose left-vs-right click discrimination, but gain correct dismissal for free.

### Hosting a SwiftUI view in a popover

```swift
import AppKit
import SwiftUI

@MainActor
final class PopoverController {
    private let popover = NSPopover()

    init(contentView: some View) {
        popover.behavior = .transient  // auto-dismiss on outside click (mostly — see anti-patterns)
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activate the app so the popover can receive keyboard input reliably.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
```

`NSHostingController` bridges the SwiftUI tree into AppKit cleanly — see `appkit-swiftui-hybrid.md` for the full pattern. Always call `NSApp.activate(ignoringOtherApps:)` before showing a popover from a menu-bar app; otherwise the popover appears but keyboard input lands in the previously active app.

## Hybrid click behavior

Common pattern: left click shows the popover, right click shows a settings menu. AppKit does not send separate events for left and right clicks on a status item button unless you opt in with `sendAction(on: [.leftMouseUp, .rightMouseUp])` (see the `StatusBarController` snippet above).

```swift
@objc private func handleClick(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }
    // Ctrl+click is the macOS convention for right click; honour both.
    let rightClick = event.type == .rightMouseUp
        || event.modifierFlags.contains(.control)
    if rightClick {
        showSettingsMenu(from: sender)
    } else {
        togglePopover(from: sender)
    }
}
```

## SwiftUI MenuBarExtra

Since macOS 13, SwiftUI has a first-class menu-bar scene: `MenuBarExtra`. It is declarative, avoids manual status-item retention, and is ideal for simple menu-bar apps.

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        MenuBarExtra("My App", systemImage: "bolt.fill") {
            AppMenuContent()
        }
        .menuBarExtraStyle(.menu)  // or .window for a popover-style panel

        Settings {
            SettingsView()
        }
    }
}
```

Trade-offs against a hand-rolled `NSStatusItem`:

- Simpler and survives view reloads, but limited control over icon rendering (no direct template-image toggling, no click-event inspection).
- `.menuBarExtraStyle(.window)` is a popover-shaped panel, not a true `NSPopover`; dismissal behavior differs subtly and you cannot customize the anchor edge.
- Distinguishing left vs right click requires extra work and sometimes an `NSViewRepresentable` escape hatch.
- Lifecycle control (showing and hiding the item dynamically) is clunky compared to direct `NSStatusItem` management.

For non-trivial menu-bar apps you will still reach for `NSStatusItem` directly. Rectangle and Ice are both built on `NSStatusItem`, not `MenuBarExtra`; see `reference-repos.md`.

## Icons and templates

Status item icons must adapt to light/dark menu bars, accent tinting, and the reduced-contrast menu bar in fullscreen. The mechanism is a **template image**: pure-black-on-transparent with `isTemplate = true`. The system inverts and tints it automatically.

```swift
// SF Symbol — already template-ready; no isTemplate toggle needed for most symbols.
button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "My App")

// Custom bundled image — must be black on transparent and marked as template.
if let image = NSImage(named: "StatusIcon") {
    image.isTemplate = true
    button.image = image
}
```

SF Symbols are the 2026 default: they ship with the OS, scale correctly across menu-bar heights (including notched MacBooks), and respect accessibility settings. Use a custom template image only when no SF Symbol fits. Shipping a custom PNG without `isTemplate = true` renders as a flat bitmap and looks wrong in dark mode and on accent-tinted menu bars.

## Global keyboard shortcut

To open the status item from a global hotkey, drive the button action yourself. This reference only covers the status-item side of the bridge — for hotkey registration (Carbon `RegisterEventHotKey`, `KeyboardShortcuts`, or `MASShortcut`), see `user-interaction.md`.

```swift
@MainActor
final class StatusBarController {
    // Called from your global-shortcut handler.
    func activateFromShortcut() {
        guard let button = statusItem.button else { return }
        // Route through the button action so right-click/left-click logic
        // stays in one place. Matches an actual click as closely as possible.
        button.performClick(nil)
    }
}
```

`performClick(nil)` is the cleanest way to simulate a click — it goes through the normal action dispatch and respects whatever `sendAction(on:)` mask you configured.

## Launch at login

Since macOS 13, `SMAppService.mainApp` is the modern launch-at-login API. It replaces the deprecated `SMLoginItemSetEnabled` and works for sandboxed apps.

```swift
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

For helper tools (launch agents / daemons registered via `SMAppService.agent(plistName:)` or `SMAppService.daemon(plistName:)`), see `system-integration.md`. The `mainApp` variant is all most menu-bar apps need.

## Hiding from Cmd+Tab

`LSUIElement = true` automatically hides the app from Cmd+Tab, the dock, and the Force Quit window. `.accessory` activation policy does the same. No separate setting is needed. Toggling `NSApp.setActivationPolicy(.accessory)` at runtime removes the app from Cmd+Tab immediately; switching back to `.regular` puts it back. This is the mechanism behind apps that switch between menu-bar and regular modes.

## Common pitfalls

- **Forgetting to retain the `StatusBarController`** — if the controller falls out of scope, the status item disappears silently. Hold it on the app delegate.
- **Using `NSPopover` when `NSMenu` would do** — popover dismissal is unreliable across spaces and Mission Control. See `anti-patterns.md`.
- **PNG icons without `isTemplate = true`** — renders flat and looks broken in dark mode or on tinted menu bars. Use SF Symbols or set `isTemplate = true`.
- **Notched MacBooks and fullscreen** — the menu bar is hidden in fullscreen on some configurations, and the notch shrinks usable width. Keep icons narrow and assume the menu bar may be unavailable.
- **Blocking the main thread in the click handler** — the menu bar is shared across every app on the system. A synchronous disk read or network call hangs the entire menu bar until it returns. Use `Task { ... }` with `async` work and update UI on `@MainActor`.
- **Forgetting `NSApp.activate(ignoringOtherApps:)` before showing a popover** — the popover appears but keyboard input goes to the previously active app. Always activate before presenting editable UI.
- **Relying on `MenuBarExtra` for custom click handling** — if you need left-vs-right discrimination, custom anchor edge, or precise dismissal, drop down to `NSStatusItem`.

## References

- Tier-1 repos: **Rectangle** (window management, `NSStatusItem` + `NSMenu`), **Ice** (menu bar manager, complex `NSStatusItem` hierarchies), **Stats** (system monitor, multiple status items with live-updating icons). All three are built on `NSStatusItem` directly, not `MenuBarExtra`. See `reference-repos.md`.
- `anti-patterns.md` — the `NSPopover`-vs-`NSMenu` rule in full.
- `system-integration.md` — `SMAppService` for agents and daemons, XPC helpers, login items beyond `mainApp`.
- `user-interaction.md` — global keyboard shortcut registration, `KeyboardShortcuts`/`MASShortcut` integration, key equivalent handling.
- `appkit-swiftui-hybrid.md` — hosting SwiftUI views inside `NSPopover` via `NSHostingController`.
- Apple documentation — search for `NSStatusItem`, `NSStatusBar`, `MenuBarExtra`, `SMAppService`, and `LSUIElement`. Verify signatures against the current SDK.
