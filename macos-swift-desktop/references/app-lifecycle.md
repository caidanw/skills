# App Lifecycle: Entry Point, AppDelegate, Menus, File Types

This reference covers how a macOS app boots, which `NSApplicationDelegate` hooks you actually need, how to build a proper main menu, and how to declare file types and URL schemes so Finder and the Dock route things to your process correctly. For `NSDocument` saving/loading, see `document-apps.md`. For `NSStatusItem` menu-bar-only apps, see `menu-bar-apps.md`. For alerts, sheets, and standard menu item patterns, see `standard-ui.md`.

## Table of contents

- [Two ways to launch a macOS app](#two-ways-to-launch-a-macos-app)
- [NSApplicationDelegate methods you actually need](#nsapplicationdelegate-methods-you-actually-need)
- [Activation policy](#activation-policy)
- [Menu setup](#menu-setup)
- [Menu validation and the responder chain](#menu-validation-and-the-responder-chain)
- [File types and document types](#file-types-and-document-types)
- [URL schemes](#url-schemes)
- [Window restoration](#window-restoration)
- [Recent documents](#recent-documents)
- [Boilerplate AppDelegate template](#boilerplate-appdelegate-template)

## Two ways to launch a macOS app

### SwiftUI `App` with an `NSApplicationDelegate` adaptor

For SwiftUI-first apps. The `App` protocol owns `Scene`s, but you still need an `NSApplicationDelegate` for anything `App` doesn't expose (URL handling, reopen, secure restorable state, custom menu validation). Wire one up with `@NSApplicationDelegateAdaptor`.

```swift
import SwiftUI

@main
struct MyApp: App {
    // The adaptor instantiates the delegate once for the process lifetime.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                // Command groups plug into the same NSMenu AppKit builds.
                CommandGroup(replacing: .newItem) { }
            }
    }
}
```

### Pure AppKit `@main` `NSApplicationDelegate`

For apps where the shell is AppKit-first (custom window management, borderless windows, Metal canvases). No SwiftUI `App` — the delegate itself is the `@main` entry point.

```swift
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = MainMenuBuilder.build()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1024, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "My App"
        window.center()
        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
```

Non-trivial SwiftUI apps still need an AppDelegate. Adopt the adaptor pattern on day one.

## NSApplicationDelegate methods you actually need

You do not need to implement every delegate method. These are the ones that matter for a typical desktop app:

| Method | When it fires | What to do |
| --- | --- | --- |
| `applicationDidFinishLaunching(_:)` | Once, after `NSApp.run()` | Set activation policy, install main menu, register URL handlers, restore windows |
| `applicationShouldTerminate(_:)` | Cmd-Q, logout, `NSApp.terminate(_:)` | Return `.terminateLater` for async save; else `.terminateNow` / `.terminateCancel` |
| `applicationWillTerminate(_:)` | Right before the process exits | Flush anything not saved. Do not block |
| `applicationShouldHandleReopen(_:hasVisibleWindows:)` | Dock-icon click when no windows are open | Re-open a window and return `true` |
| `application(_:open:)` | Finder double-click, drop on Dock, `open -a` | Open each `URL`; called with the full batch, not one-by-one |
| `application(_:openFile:)` | Legacy single-file open (pre-`URL` API) | Forward to the modern handler if you still need it |
| `applicationSupportsSecureRestorableState(_:)` | Once during launch | Return `true` on macOS 14+ to silence the warning and use `NSSecureCoding` |

Exact signatures have shifted across macOS versions — verify against the current SDK or Apple's `NSApplicationDelegate` documentation before relying on an uncommon variant.

## Activation policy

`NSApp.setActivationPolicy(_:)` controls whether the app appears in the Dock, the menu bar, or neither.

```swift
NSApp.setActivationPolicy(.regular)    // Dock icon + main menu. The default.
NSApp.setActivationPolicy(.accessory)  // No Dock icon, no menu bar until activated
NSApp.setActivationPolicy(.prohibited) // Background-only helper; never steals focus
```

Two ways to start up as a menu-bar app:

1. **`Info.plist` `LSUIElement = YES`** — launches directly as accessory. Static; cannot toggle at runtime. Use when the app should never have a Dock icon.
2. **`setActivationPolicy(.accessory)` at runtime** — use when the app switches between menu-bar-only and Dock-presence modes. Apps like Ice and Rectangle swap policy while a preferences window is briefly open.

See `menu-bar-apps.md` for `NSStatusItem` wiring and the full pattern.

## Menu setup

On macOS the menu bar is not optional. Install one or the system shows only "Apple menu + app name + Quit" and users will assume the app is broken. Storyboards work but hide what's going on. A programmatic menu is easier to reason about and version-control. Build once during launch and assign to `NSApp.mainMenu`.

```swift
enum MainMenuBuilder {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(appMenu())
        main.addItem(editMenu())
        main.addItem(windowMenu())
        // File, View, Help follow the same pattern.
        return main
    }

    private static func appMenu() -> NSMenuItem {
        let name = ProcessInfo.processInfo.processName
        let menu = NSMenu(title: "App")
        menu.addItem(withTitle: "About \(name)",
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide \(name)",
                     action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: "Quit \(name)",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return wrap(menu)
    }

    private static func editMenu() -> NSMenuItem {
        // System-defined selectors. Targeting nil sends actions down the
        // responder chain. Custom names break NSText/NSTextView dispatch.
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All",
                     action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return wrap(menu)
    }

    private static func windowMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize",
                     action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = menu  // AppKit auto-populates open windows here
        return wrap(menu)
    }

    private static func wrap(_ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(); item.submenu = submenu; return item
    }
}
```

Every macOS app should expose: an **app menu** (About, Services, Hide, Quit), **File** (New, Open, Open Recent, Save, Close), **Edit** (Undo/Redo, Cut/Copy/Paste/Select All), **View**, **Window** (Minimize, Zoom, Bring All to Front — auto-populated once `NSApp.windowsMenu` is set), and **Help** (set `NSApp.helpMenu` for the system Help search field). Standard edit commands **must** use the system selectors shown above; custom selectors break built-in text field dispatch. Full menu conventions live in `standard-ui.md`; CotEditor's `MainMenu.xib` and CodeEdit's `CodeEditApplication+Menu.swift` are both worth cloning and reading.

## Menu validation and the responder chain

Menu items enable and disable themselves via `NSMenuItemValidation`. When the user opens a menu, AppKit walks the responder chain asking each object "can you handle this action?"

```swift
final class EditorViewController: NSViewController, NSMenuItemValidation {
    private var hasSelection = false

    @objc func copy(_ sender: Any?) { /* ... copy to NSPasteboard ... */ }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(copy(_:)): return hasSelection
        // Let the next responder have a shot at actions we don't own.
        default: return true
        }
    }
}
```

Dispatch order for an action with a `nil` target: key window's **first responder** and its responder chain → key window's **delegate** → main window's first responder and delegate (if different) → `NSApp.delegate` → `NSApplication` itself. This is how `Cmd+S` knows which window to save: the save action is posted to `nil`, AppKit walks the chain from the key window, and the document attached to that window's window controller picks it up.

## File types and document types

Declare what the app reads and writes in `Info.plist`:

- **`CFBundleDocumentTypes`** — UTIs the app opens. Finder uses these for "Open With" and double-click routing.
- **`UTExportedTypeDeclarations`** — custom UTIs the app defines (your own format).
- **`UTImportedTypeDeclarations`** — custom UTIs the app consumes but does not own.

Exported type for a fictional `.mything` format:

```xml
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key><string>com.example.mything</string>
        <key>UTTypeDescription</key><string>MyThing Document</string>
        <key>UTTypeConformsTo</key>
        <array><string>public.data</string><string>public.content</string></array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array><string>mything</string></array>
        </dict>
    </dict>
</array>
```

Reference the UTI from `CFBundleDocumentTypes` so Finder routes `.mything` files to the app. For `NSDocument` apps the rest is automatic; for non-document apps, handle opens in `application(_:open:)`. See `document-apps.md` for `NSDocument` specifics.

## URL schemes

Register a custom scheme in `Info.plist` under `CFBundleURLTypes`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key><string>com.example.myapp</string>
        <key>CFBundleURLSchemes</key>
        <array><string>myapp</string></array>
    </dict>
</array>
```

Handle incoming URLs in the AppDelegate:

```swift
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.scheme == "myapp" {
        URLRouter.shared.handle(url)
    }
}
```

SwiftUI's equivalent scene modifier is `.onOpenURL { url in ... }` on any `Scene`. For opening external URLs from SwiftUI views, inject `@Environment(\.openURL) private var openURL` and call `openURL(url)` from an action closure.

## Window restoration

SwiftUI `Scene`s get restoration for free — `WindowGroup` preserves window frames, selection, and most scene state without code.

For AppKit, windows adopt `NSWindowRestoration` and AppKit rebuilds each window from state encoded into `encodeRestorableState(with:)`. Return `true` from `applicationSupportsSecureRestorableState(_:)` on macOS 14+ so state coding uses `NSSecureCoding`. A full implementation is out of scope here — see Apple's "Preserving Your App's UI Across Launches" and CotEditor's `DocumentWindowController`.

## Recent documents

`NSDocumentController` maintains "Open Recent" automatically for `NSDocument` apps. For non-document apps, call `noteNewRecentDocumentURL(_:)` manually when the user opens a file:

```swift
func openProject(at url: URL) {
    // Load, then tell the system this URL goes in Open Recent.
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    projectController.load(url: url)
    NSDocumentController.shared.noteNewRecentDocumentURL(url)
}
```

AppKit populates the `File -> Open Recent` submenu as long as the File menu exists and `NSDocumentController` has recorded URLs.

## Boilerplate AppDelegate template

Minimum viable `AppDelegate` — activation policy, menu, terminate confirmation, URL handling, secure restorable state. Copy and adapt; replace singletons with whatever matches the app's architecture.

```swift
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = MainMenuBuilder.build()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UnsavedChangesTracker.shared.hasUnsavedWork else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Save changes before quitting?"
        ["Save", "Discard", "Cancel"].forEach { alert.addButton(withTitle: $0) }
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            UnsavedChangesTracker.shared.saveAll(); return .terminateNow
        case .alertSecondButtonReturn: return .terminateNow
        default: return .terminateCancel
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowRouter.shared.showMainWindow() }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { URLRouter.shared.handle(url) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        UnsavedChangesTracker.shared.flushPending()
    }
}
```

## References

- `document-apps.md` — `NSDocument` / `FileDocument` lifecycle, autosave, versioning, file coordination
- `menu-bar-apps.md` — `LSUIElement`, `NSStatusItem`, accessory activation policy
- `standard-ui.md` — menus, alerts, sheets, popovers, dock badges
- Apple — `NSApplicationDelegate` and "App lifecycle and life cycle events"
- Apple — "Preserving Your App's UI Across Launches" (window restoration)
- Rectangle (`AppDelegate.swift`) — accessory-policy menu-bar app with prefs window
- CotEditor (`AppDelegate.swift`, `MainMenu.xib`) — document AppKit app with a rich main menu
- CodeEdit (`CodeEditorApp.swift`, `CodeEditApplication+Menu.swift`) — hybrid SwiftUI `App` + adaptor with programmatic menu customization
