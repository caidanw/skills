# Anti-patterns: what NOT to do when building macOS desktop apps in Swift

This reference lists the mistakes that most reliably wreck a macOS app: dismissal bugs in menu bar UIs, sandbox violations on user files, crashes on VMs from force-unwrapped Metal calls, blocked menu bar clicks, and secrets leaking via `UserDefaults`. Each entry has a one-line "don't", a short diagnosis, and a concrete alternative — either a code pair or a pointer to the reference doc that covers the correct pattern. The last section is a ten-item red-flag checklist for reviewing existing code.

## Table of contents

- [1. NSPopover for menu bar UI](#1-nspopover-for-menu-bar-ui)
- [2. Pure SwiftUI for non-trivial desktop apps](#2-pure-swiftui-for-non-trivial-desktop-apps)
- [3. Missing sandbox or notarization](#3-missing-sandbox-or-notarization)
- [4. Large NSOutlineView without virtualization](#4-large-nsoutlineview-without-virtualization)
- [5. Hardcoded file paths instead of NSOpenPanel + bookmarks](#5-hardcoded-file-paths-instead-of-nsopenpanel--bookmarks)
- [6. Ignoring Task.isCancelled in long-running work](#6-ignoring-taskiscancelled-in-long-running-work)
- [7. Custom undo stack instead of NSUndoManager](#7-custom-undo-stack-instead-of-nsundomanager)
- [8. Privileged operations in the main app process](#8-privileged-operations-in-the-main-app-process)
- [9. Force-unwrapping Apple APIs that can return nil](#9-force-unwrapping-apple-apis-that-can-return-nil)
- [10. Writing preferences into the app bundle or Documents directory](#10-writing-preferences-into-the-app-bundle-or-documents-directory)
- [11. Blocking the main thread inside a menu bar click handler](#11-blocking-the-main-thread-inside-a-menu-bar-click-handler)
- [12. Storing secrets in UserDefaults or plist files](#12-storing-secrets-in-userdefaults-or-plist-files)
- [13. Subclassing NSTextView or NSScrollView for customization](#13-subclassing-nstextview-or-nsscrollview-for-customization)
- [Red flags when reviewing code](#red-flags-when-reviewing-code)

## 1. NSPopover for menu bar UI

**Don't:** attach an `NSPopover` to an `NSStatusItem` button and treat it as the menu bar surface.
**Why:** popovers have long-standing dismissal bugs (they fail to close on resign-key, fight Mission Control, and eat first-responder state), they don't participate in menu validation, and they don't feel native next to any other status item on the bar.
**Do this instead:** use `NSMenu` attached to the status item. Build submenus from data, use `validateMenuItem(_:)` for enable/disable state, and drop to an `NSWindow` if you genuinely need a rich panel. Full patterns in `menu-bar-apps.md`.

## 2. Pure SwiftUI for non-trivial desktop apps

**Don't:** ship a multi-window, document-based, menu-bar, or borderless-window app written entirely in SwiftUI's `App` / `WindowGroup` / `Scene` tree.
**Why:** SwiftUI on macOS still lacks reliable APIs for addressing individual windows, custom chrome, system tray, per-menu-item validation, and the first-responder chain. You will hit a wall and refactor mid-project.
**Do this instead:** start with an AppKit shell (`NSApplicationDelegate`, `NSWindowController`, `NSSplitViewController`) and host SwiftUI content via `NSHostingController`. See `appkit-swiftui-hybrid.md` for the decision matrix and bridging patterns.

## 3. Missing sandbox or notarization

**Don't:** distribute an unsigned, non-sandboxed, non-notarized `.app` — even for internal tools.
**Why:** Gatekeeper quarantines downloaded apps; users see a "cannot be opened because the developer cannot be verified" or "malicious software" dialog on first launch. On macOS 15+ the override path requires a trip to System Settings that most users will not take.
**Do this instead:** codesign with a Developer ID certificate and the hardened runtime, enable App Sandbox entitlement (required for the Mac App Store, recommended otherwise), and notarize with `notarytool` before distributing. See `distribution.md` for the full pipeline.

## 4. Large NSOutlineView without virtualization

**Don't:** load 10k+ rows into `NSOutlineView` with all children pre-expanded and all items materialized up front.
**Why:** `NSOutlineView` materializes every visible row; fully expanding a deep tree hangs the UI, and its insert/remove animations cannot be fully disabled — batch updates still spend time animating rows you never see.
**Do this instead:** implement lazy children in `NSOutlineViewDataSource` (`outlineView(_:numberOfChildrenOfItem:)` and `outlineView(_:child:ofItem:)` fetch on demand), or switch to `NSCollectionView` with a list layout when the source is genuinely flat. For a production lazy-outline example see the SourceView sample in `reference-repos.md`.

## 5. Hardcoded file paths instead of NSOpenPanel + bookmarks

**Don't:** hardcode `~/Documents/MyApp/` or build absolute paths from `NSHomeDirectory()` for user content.
**Why:** sandboxed apps cannot read arbitrary paths without user consent — the call silently fails or throws. Mac App Store review rejects the app outright. Even non-sandboxed apps break when the user moves their home or uses an external volume.
**Do this instead:** present an `NSOpenPanel` with `allowedContentTypes`, obtain a security-scoped bookmark via `bookmarkData(options: .withSecurityScope)`, persist the bookmark, and resolve it with `startAccessingSecurityScopedResource()` on next launch. See `user-interaction.md` for open/save panels and `document-apps.md` for document-scoped bookmarks.

## 6. Ignoring Task.isCancelled in long-running work

**Don't:** assume a Swift `Task` stops on its own when the view that started it goes away.
**Why:** structured concurrency propagates cancellation as a signal — it does not forcibly stop CPU-bound work. A detached task that never checks the signal keeps burning battery after the user navigates away.

```swift
// Don't
func reindex(files: [URL]) async throws -> [Entry] {
    var result: [Entry] = []
    for url in files {
        result.append(try await parse(url))
    }
    return result
}
```

```swift
// Do this instead
func reindex(files: [URL]) async throws -> [Entry] {
    var result: [Entry] = []
    for url in files {
        try Task.checkCancellation()       // throws CancellationError
        result.append(try await parse(url))
    }
    return result
}
```

Use `try Task.checkCancellation()` inside loops and `if Task.isCancelled { return }` when you want a silent early-out. Cancel the parent task when the owning view disappears.

## 7. Custom undo stack instead of NSUndoManager

**Don't:** build a bespoke `[Command]` stack with your own `undo()` / `redo()` methods.
**Why:** users expect `Cmd+Z` and `Cmd+Shift+Z` to work everywhere, including inside text fields and across the responder chain. A custom stack does not integrate with AppKit's undo menu items, does not coalesce typing, does not respect document edited state, and does not propagate through `NSDocument`.
**Do this instead:** use the `undoManager` property available on `NSResponder`, `NSDocument`, and SwiftUI's environment. Register inverse operations with `registerUndo(withTarget:handler:)` and set `setActionName(_:)` so the menu item reads "Undo Rename". See `user-interaction.md` for the full pattern.

## 8. Privileged operations in the main app process

**Don't:** call into `Authorization Services`, write to `/Library`, install launchd agents, or run helper tools from your sandboxed main process.
**Why:** the main app process is the wrong trust boundary for privileged work. Sandbox entitlements are all-or-nothing on the main process, and a compromise of the UI process should not imply a compromise of the privileged capability.
**Do this instead:** split privileged work into an XPC service or a privileged helper installed via `SMAppService`. The main app communicates with the helper over a typed `NSXPCConnection`. See `system-integration.md` for XPC patterns and `reference-repos.md` for Xcodes.app, which ships a production privileged helper for installing Xcode.

## 9. Force-unwrapping Apple APIs that can return nil

**Don't:** force-unwrap fallible Apple APIs with `!`, `try!`, or `as!`.
**Why:** `MTLCreateSystemDefaultDevice()` returns `nil` on VMs and very old Macs; `NSImage(named:)` returns `nil` when the asset catalog hasn't been loaded yet or the name is typoed; `Bundle.main.url(forResource:withExtension:)` returns `nil` when the resource is missing from a particular build configuration. A force-unwrap turns a recoverable edge case into a crash on someone else's Mac.

```swift
// Don't
let device = MTLCreateSystemDefaultDevice()!
let icon = NSImage(named: "AppIcon")!
let config = try! JSONDecoder().decode(Config.self, from: data)
```

```swift
// Do this instead
guard let device = MTLCreateSystemDefaultDevice() else {
    logger.error("Metal unavailable; falling back to CPU renderer")
    return .cpuFallback
}
guard let icon = NSImage(named: "AppIcon") else {
    logger.error("AppIcon missing from bundle")
    return
}
let config: Config
do {
    config = try JSONDecoder().decode(Config.self, from: data)
} catch {
    logger.error("Config decode failed: \(error)")
    return
}
```

Reserve `!` and `try!` for genuinely unreachable cases (and even then, prefer `fatalError(_:)` with a message).

## 10. Writing preferences into the app bundle or Documents directory

**Don't:** write settings or caches into `Bundle.main.bundleURL` or the user's `Documents` folder.
**Why:** signed app bundles are read-only — writes silently fail or invalidate the signature on unsigned builds. `Documents` is for user-visible files; polluting it creates Finder clutter on macOS and is actively wrong on iOS.
**Do this instead:** use `UserDefaults` for small settings, `FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, ...)` for app data, and `.cachesDirectory` for regenerable data that the system may purge. See `persistence.md` for the directory matrix and Core Data / SwiftData / GRDB stores.

## 11. Blocking the main thread inside a menu bar click handler

**Don't:** perform network requests, disk scans, or synchronous waits inside the target-action callback of an `NSStatusItem` button or menu item.
**Why:** the menu bar is a shared resource — blocking the main thread freezes the menu bar for every app until your call returns. Users notice immediately, and the app gets the "beach ball" reputation.

```swift
// Don't
@objc func refreshClicked(_ sender: Any) {
    let data = try? Data(contentsOf: apiURL)   // blocks main thread
    updateMenu(with: data)
}
```

```swift
// Do this instead
@objc func refreshClicked(_ sender: Any) {
    menuItem.title = "Refreshing..."
    Task { @MainActor in
        let data = try? await URLSession.shared.data(from: apiURL).0
        updateMenu(with: data)
    }
}
```

Dispatch to a background task immediately, show a loading state in the menu, and update when the work finishes.

## 12. Storing secrets in UserDefaults or plist files

**Don't:** write API tokens, OAuth refresh tokens, or passwords to `UserDefaults`, a plist in Application Support, or a JSON file on disk.
**Why:** `UserDefaults` is plain text in `~/Library/Preferences/`, included in Time Machine backups, readable by any process with the user's privileges, and trivially dumpable with `defaults read`. Plist and JSON files have the same problem.
**Do this instead:** use Keychain Services with a `kSecClassGenericPassword` item scoped to your app's bundle identifier. Apps distributed outside the Mac App Store can use an access group; sandboxed apps get per-app keychain partitioning automatically. See `persistence.md` for the Keychain wrapper pattern.

## 13. Subclassing NSTextView or NSScrollView for customization

**Don't:** subclass `NSTextView` or `NSScrollView` and override private-feeling methods to change layout, scrolling physics, or selection behavior.
**Why:** both classes have deep internal state that Apple rewrites between macOS versions. A subclass that hooks `layout()`, `scrollWheel(with:)`, or `setSelectedRanges(_:)` will break on the next major release and is painful to test.
**Do this instead:** use delegate protocols (`NSTextViewDelegate`, `NSTextStorageDelegate`), subclass `NSTextLayoutManager` / `NSTextContentStorage` for TextKit 2 customization, or build a fresh TextKit 2 custom view following the STTextView pattern. See `reference-repos.md` for STTextView as the canonical example of a custom text view built on TextKit 2.

## Red flags when reviewing code

Stop and reconsider when you see any of the following:

- `!` force-unwrap on an Apple API return value
- `DispatchQueue.main.sync` anywhere
- `NSPopover` attached to an `NSStatusItem` button
- `try!` or `as!` in production code
- `UserDefaults.standard.set(token, forKey: "apiKey")`
- `NSApp.runModal` blocking the event loop during user flow
- Custom undo stack without `NSUndoManager`
- `.xcconfig` missing `CODE_SIGN_IDENTITY`
- Missing `allowedContentTypes` on an `NSOpenPanel`
- `NSView` subclass with no `accessibilityLabel()`
