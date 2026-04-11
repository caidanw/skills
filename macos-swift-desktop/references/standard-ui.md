# Standard macOS UI: Menus, Alerts, Sheets, Popovers, Modals, Dock

This reference covers the standard presentation primitives a macOS app reaches for daily: building `NSMenu` in code, showing `NSAlert`, presenting sheets and popovers, open/save panels, dock tile badges, toolbars, and tooltips. It is scoped to generic standard UI — menu-bar / `NSStatusItem` apps live in `menu-bar-apps.md`, drag-drop and pasteboard live in `user-interaction.md`, and `NSDocument` save flows live in `document-apps.md`.

## Table of contents

- [NSMenu programmatically](#nsmenu-programmatically)
- [NSAlert — the modern way](#nsalert--the-modern-way)
- [Sheets](#sheets)
- [NSPopover](#nspopover)
- [Modal windows](#modal-windows)
- [SwiftUI presentations (for hybrid apps)](#swiftui-presentations-for-hybrid-apps)
- [Open/save panels](#opensave-panels)
- [Dock tile and badge](#dock-tile-and-badge)
- [Toolbars](#toolbars)
- [Tooltips and Help](#tooltips-and-help)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## NSMenu programmatically

`NSMenu` is trivially built in code. Each `NSMenuItem` carries a title, an action selector, and a key equivalent. Items without an explicit `target` dispatch through the responder chain — this is how `Cmd+C` lands on whichever view is first responder.

```swift
import AppKit

@MainActor
func makeEditMenu() -> NSMenu {
    let menu = NSMenu(title: "Edit")

    // Responder-chain dispatch: target is nil, so AppKit walks the chain
    // looking for an object that responds to the selector. This is why
    // first responder matters for menu validation.
    menu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
    menu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    menu.addItem(.separator())

    // Nested submenu. An item with a submenu uses `action: nil`.
    let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
    let findMenu = NSMenu(title: "Find")
    let finderAction = #selector(NSResponder.performTextFinderAction(_:))
    findMenu.addItem(NSMenuItem(title: "Find…", action: finderAction, keyEquivalent: "f"))
    findMenu.addItem(NSMenuItem(title: "Find Next", action: finderAction, keyEquivalent: "g"))
    findItem.submenu = findMenu
    menu.addItem(findItem)
    return menu
}
```

A contextual menu is any `NSMenu` returned from a view. Override `menu(for:)` so you can populate it against the hit-tested item per event:

```swift
final class CanvasObjectView: NSView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Rename…", action: #selector(rename(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Duplicate", action: #selector(duplicate(_:)), keyEquivalent: "d"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(delete(_:)), keyEquivalent: ""))
        return menu
    }
}
```

Targets set here default to `self`, so contextual menus tend to bypass the responder chain — set `item.target = nil` explicitly if you want responder-chain dispatch.

## NSAlert — the modern way

`NSAlert` is the right primitive for confirmations, warnings, and errors. Build one, add buttons in order (first = default, second = cancel, third = destructive), and present as a window-modal sheet. Never call `runModal()` if a parent window is available — that blocks the whole app.

```swift
@MainActor
func confirmDelete(in window: NSWindow, itemName: String) async -> Bool {
    let alert = NSAlert()
    alert.messageText = "Delete \(itemName)?"
    alert.informativeText = "This cannot be undone."
    alert.alertStyle = .warning
    // First button is the default (Return). HIG: make Cancel the default
    // on destructive confirmations so Return is safe.
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Delete")
    alert.buttons.last?.hasDestructiveAction = true  // Red tint on macOS 11+

    // Async window-modal sheet. Completion-handler form still works when
    // you can't `await`: `alert.beginSheetModal(for: window) { response in ... }`
    let response = await alert.beginSheetModal(for: window)
    return response == .alertSecondButtonReturn
}
```

Alert style picker:

| Style             | Use for                                                         |
| ---               | ---                                                             |
| `.informational`  | Neutral notices ("Update available", "Import complete")         |
| `.warning`        | Confirmations where the user might lose work (default choice)   |
| `.critical`       | Destructive, irrecoverable operations ("Erase disk", "Quit without saving") |

`.critical` draws a caution badge over the app icon; reserve it for genuinely dangerous paths.

## Sheets

A sheet is a child window attached to a parent window; input to the parent is blocked until the sheet dismisses, but the rest of the app keeps running. Sheets are the right primitive for "save before quit", "confirm destructive action", and multi-step modal flows like a sign-in or import wizard.

```swift
// AppKit: present a window controller as a sheet.
@MainActor
func presentImportSheet(from parent: NSWindow) {
    let importer = ImportWindowController()  // loads its own NSWindow
    guard let sheetWindow = importer.window else { return }
    parent.beginSheet(sheetWindow) { response in
        // response is an NSApplication.ModalResponse set by endSheet(_:)
        if response == .OK { print("import accepted") }
    }
}

// Inside the sheet's controller, dismiss with:
// view.window?.sheetParent?.endSheet(view.window!, returnCode: .OK)
```

SwiftUI equivalent in a hybrid app:

```swift
struct ContentView: View {
    @State private var showingImporter = false

    var body: some View {
        Button("Import…") { showingImporter = true }
            .sheet(isPresented: $showingImporter) { ImporterView() }
    }
}
```

## NSPopover

`NSPopover` is a small transient UI anchored to a view — good for inline editors ("edit tag", "pick a color"), disclosure panels, and quick inspectors. It is **not** a replacement for `NSMenu`, and not the right pattern for menu-bar apps (see `menu-bar-apps.md` for why).

```swift
@MainActor
final class TagEditorPresenter {
    private let popover = NSPopover()

    init() {
        popover.behavior = .transient          // Click outside to dismiss
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: TagEditorView())
    }

    func show(relativeTo view: NSView) {
        popover.show(of: view.bounds, of: view, preferredEdge: .maxY)
    }
}
```

Pitfalls:

- `.transient` dismisses on any click outside — including clicks on other app windows. Use `.semitransient` if you need the popover to stay visible while the user interacts with a detached tool window.
- Popovers capture first responder on show; key equivalents in the parent window are blocked until dismissal.
- Setting `contentSize` vs letting SwiftUI infer the size is inconsistent across macOS versions — set `contentSize` explicitly for deterministic layout.

## Modal windows

`NSApp.runModal(for:)` runs an app-modal session that blocks the entire application until the window ends its modal session. It still works but it blocks every window the app owns, including other documents — almost never what you want on macOS.

```swift
// Legacy — avoid unless there is truly no parent window.
let response = NSApp.runModal(for: alertWindow)
if response == .OK { /* ... */ }
// The window must call NSApp.stopModal(withCode:) to unblock runModal.
```

Prefer window-modal sheets (`beginSheet(_:completionHandler:)`) in every case where a parent window exists. Reserve `runModal` for launcher-style apps with no main window, or for one-off error dialogs at startup before any window has been created.

## SwiftUI presentations (for hybrid apps)

| AppKit                           | SwiftUI equivalent               |
| ---                              | ---                              |
| `NSAlert.beginSheetModal`        | `.alert(_:isPresented:actions:)` |
| Sheet window                     | `.sheet(isPresented:content:)`   |
| `NSPopover`                      | `.popover(isPresented:content:)` |
| Multi-button confirmation        | `.confirmationDialog(...)`       |
| `NSOpenPanel` / `NSSavePanel`    | `.fileImporter` / `.fileExporter` |

Pick one presentation strategy per screen. Mixing an AppKit `beginSheet(_:)` and a SwiftUI `.sheet(isPresented:)` in the same window causes z-order bugs: the AppKit sheet can appear under a SwiftUI sheet, or SwiftUI can animate its sheet over a running AppKit sheet session and leave the responder chain in an inconsistent state. When the outer window is AppKit (the common hybrid case), drive all sheets from AppKit and let SwiftUI render inside them via `NSHostingController`.

## Open/save panels

`NSOpenPanel` and `NSSavePanel` are sheets when attached to a parent window; use `beginSheetModal(for:completionHandler:)` or `begin(_:)` for the async form. Configure with `UTType` values from `UniformTypeIdentifiers` — the `allowedFileTypes` string-based API is deprecated.

```swift
import AppKit
import UniformTypeIdentifiers

@MainActor
func pickImages(in window: NSWindow) async -> [URL] {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image, .png, .jpeg]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.prompt = "Import"

    // begin(_:) returns on the main actor with the user's response.
    let response = await panel.beginSheetModal(for: window)
    return response == .OK ? panel.urls : []
}
```

Cross-link: `user-interaction.md` for drag-drop, pasteboard, and persistent access via security-scoped bookmarks.

## Dock tile and badge

The dock tile is `NSApp.dockTile`. The two hooks you reach for most:

```swift
// Badge string (usually a small integer count).
NSApp.dockTile.badgeLabel = unreadCount > 0 ? "\(unreadCount)" : nil

// Custom content view: any NSView. display() triggers a redraw.
let progressView = DockProgressView()
NSApp.dockTile.contentView = progressView
NSApp.dockTile.display()
```

A long-running operation with a progress indicator in the dock icon is a classic macOS pattern:

```swift
@MainActor
final class DockProgressIndicator {
    private let tile = NSApp.dockTile
    private let bar = NSProgressIndicator(frame: NSRect(x: 8, y: 8, width: 112, height: 16))

    init() {
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        tile.contentView = bar
    }

    func update(_ fraction: Double) { bar.doubleValue = fraction; tile.display() }
    func finish() { tile.contentView = nil; tile.badgeLabel = nil; tile.display() }
}
```

`display()` is required after any change — the dock tile does not observe its content view.

## Toolbars

`NSToolbar` is the canonical programmatic API. You supply an `NSToolbarDelegate` that vends `NSToolbarItem` instances by identifier, plus ordered lists of default and allowed identifiers.

```swift
final class MainToolbarDelegate: NSObject, NSToolbarDelegate {
    static let newItem = NSToolbarItem.Identifier("new")
    static let shareItem = NSToolbarItem.Identifier("share")

    func toolbarDefaultItemIdentifiers(_ t: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.newItem, .flexibleSpace, Self.shareItem]
    }
    func toolbarAllowedItemIdentifiers(_ t: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.newItem, Self.shareItem, .flexibleSpace, .space]
    }
    func toolbar(_ t: NSToolbar,
                 itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        let symbol = id == Self.newItem ? "plus" : "square.and.arrow.up"
        item.label = id == Self.newItem ? "New" : "Share"
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: item.label)
        item.isBordered = true
        return item
    }
}

// Attach during window setup.
let toolbar = NSToolbar(identifier: "main")
toolbar.delegate = toolbarDelegate
window.toolbar = toolbar
```

In SwiftUI, `.toolbar { ToolbarItem { ... } }` is the declarative equivalent and is enough for simple cases. For rich, customizable, restorable toolbars, drive `NSToolbar` from AppKit — **CodeEdit's `MainToolbar.swift`** is the canonical programmatic example. A full toolbar treatment (customization sheet, tracking-separator items, sidebar accessory views) deserves its own reference.

## Tooltips and Help

Every `NSView` exposes `toolTip: String?`. Setting it registers the view for tracking and displays the string after the system hover delay:

```swift
button.toolTip = "Create a new document (Cmd+N)"
```

For view-region tooltips that depend on hit position, use `addToolTip(_:owner:userData:)`, which calls `view(_:stringForToolTip:point:userData:)` on the owner whenever the cursor enters a region.

`NSHelpManager.shared` handles context help (`?` cursor mode) — bind a help anchor per view with `NSHelpManager.shared.setContextHelp(_:for:)` and the system displays it from your bundled `.help` file. Most apps skip context help entirely in favor of tooltips and a Help menu item that opens online documentation.

## Common pitfalls

- **Building the main menu from `init` before the window exists.** `NSApp.mainMenu = ...` must run after `NSApplication` is initialized; do it in `applicationDidFinishLaunching(_:)` or a `@main`'s `init`, not during static initialization.
- **Calling `NSAlert.runModal()` from inside an event handler.** Re-entering a modal session while an event is mid-dispatch can deadlock the run loop or crash on assertion. Use `beginSheetModal(for:)` when a window is available, or dispatch to the next run-loop turn.
- **Using `NSPopover` for menu-bar UI.** Popovers have transient-dismissal bugs when the user interacts with other apps and don't feel native in the menu bar. Use `NSMenu` — see `anti-patterns.md` and `menu-bar-apps.md`.
- **Mixing AppKit and SwiftUI sheet presentation in the same window.** Pick one. In a hybrid app with an AppKit window shell, drive sheets from AppKit and let SwiftUI live inside the sheet via `NSHostingController`.
- **Forgetting `tile.display()` after mutating the dock tile's `contentView`.** The tile does not auto-redraw; changes are invisible until you call `display()`.
- **Setting `allowedFileTypes` on `NSOpenPanel`.** Deprecated — use `allowedContentTypes: [UTType]`.

## References

- `menu-bar-apps.md` — `NSStatusItem`, `LSUIElement`, why not to use `NSPopover` for menu-bar UI
- `user-interaction.md` — drag-and-drop, pasteboard, security-scoped bookmarks for `NSOpenPanel` results
- `anti-patterns.md` — the full "don't do this" list, including popover-for-menu-bar and pure-SwiftUI-for-complex-shells
- `appkit-swiftui-hybrid.md` — `NSHostingController` for sheet contents, Coordinator pattern
- **CodeEdit** — `MainToolbar.swift` as the canonical programmatic `NSToolbar` example (see `reference-repos.md`)
- **CotEditor** — production `NSAlert` usage patterns for save/revert/encoding confirmations
- Apple HIG — [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers), [Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
