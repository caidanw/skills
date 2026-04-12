---
name: macos-swift-desktop
description: "Build native macOS desktop applications in Swift using AppKit and SwiftUI. Use when building or modifying macOS .app bundles, NSDocument-based apps, menu bar apps, preferences windows, NSWindow/NSToolbar/NSSplitView layouts, NSMenu/NSStatusItem, Core Data/SwiftData/GRDB persistence, drag-and-drop, undo/redo, sandboxing, notarization, Sparkle auto-updates, XPC helpers, or XCTest for macOS. Also covers GPU-accelerated rendering with Metal and CAMetalLayer, infinite canvas UIs, libghostty terminal embedding, and WKWebView embedding. Trigger on AppKit, NSApplicationDelegate, NSDocument, NSViewController, Swift+Metal, macOS code signing, or when a user asks for production-grade Swift desktop patterns from repos like CodeEdit, Rectangle, CotEditor, IINA, Ice, Stats, Xcodes.app, STTextView, or Ghostty."
---

# macOS Swift Desktop

Build native macOS desktop apps in Swift. This skill is topic-organized: `SKILL.md` is the index and routing table; detailed patterns and code live in `references/`.

## When to use this skill

- Building or modifying a macOS `.app` bundle (AppKit, SwiftUI, or hybrid)
- Document-based apps (`NSDocument`, `FileDocument`)
- Menu bar apps (`NSStatusItem`)
- Preferences windows, toolbars, split views, inspectors
- Persistence (Core Data, SwiftData, GRDB/SQLite, `UserDefaults`, Keychain)
- Undo/redo, drag-and-drop, pasteboard, keyboard shortcuts, accessibility
- Sandboxing, entitlements, code signing, notarization, Sparkle auto-updates
- XPC helpers, `SMAppService`, Shortcuts/Intents, FileProvider, Handoff
- XCTest, `XCUIApplication`, `OSLog`, Instruments, crash reporting
- GPU-accelerated rendering with Metal, infinite canvases, libghostty, WKWebView embedding

If the task is pure Swift language questions from a TypeScript/Python background, read `references/swift-for-ts-devs.md`.

## Mental model: AppKit + SwiftUI hybrid

**Always use the hybrid pattern for non-trivial desktop apps.** Pure SwiftUI is missing too much: custom Metal rendering, fine-grained gesture control, low-level window management, borderless/transparent windows, and multi-window coordination. Pure AppKit is verbose for forms, settings, and standard controls.

```
┌───────────────────────────────────────────┐
│  App lifecycle (AppKit)                    │
│  NSApplicationDelegate, NSWindow,          │
│  NSWindowController, NSDocument            │
│                                            │
│  ┌─────────────────────────────────────┐  │
│  │  Window chrome (SwiftUI or AppKit)  │  │
│  │  Toolbar, sidebar, inspector,        │  │
│  │  settings, forms                     │  │
│  │                                      │  │
│  │  ┌────────────────────────────────┐ │  │
│  │  │  Content view (custom NSView    │ │  │
│  │  │  if performance-critical —      │ │  │
│  │  │  Metal, text editor, canvas)    │ │  │
│  │  └────────────────────────────────┘ │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

**Rule of thumb:** AppKit owns the structural shell (windows, split views, toolbars, documents). SwiftUI owns the content panels (sidebars, inspectors, settings). Performance-critical views (text editors, terminals, Metal canvases) are custom `NSView` subclasses embedded via `NSViewRepresentable`.

Full details and code: `references/appkit-swiftui-hybrid.md`

## Routing table

If the task involves...                                                                   | Read
---                                                                                        | ---
App startup, `@main`, `NSApplicationDelegate`, menu validation, file type registration    | `references/app-lifecycle.md`
Opening, saving, autosaving files; `NSDocument` / `FileDocument` / file coordination      | `references/document-apps.md`
Menus, alerts, sheets, popovers, modals, dock badges                                       | `references/standard-ui.md`
Menu bar apps (`NSStatusItem`, `LSUIElement`, activation policy)                           | `references/menu-bar-apps.md`
Window geometry, multi-screen, fullscreen, frame restoration                               | `references/windows-and-geometry.md`
Core Data / SwiftData / GRDB / `UserDefaults` / Keychain                                   | `references/persistence.md`
Undo/redo, drag-and-drop, pasteboard, `NSOpenPanel`/`NSSavePanel`, shortcuts, accessibility | `references/user-interaction.md`
Sandbox, entitlements, code signing, notarization, Sparkle                                 | `references/distribution.md`
XCTest, UI tests, Instruments, `OSLog`, signposts, crash reporting                         | `references/testing-and-observability.md`
XPC services, `SMAppService`, `AppIntent`, `NSUserActivity`, FileProvider                  | `references/system-integration.md`
AppKit+SwiftUI bridging, `NSHostingView`, `NSViewRepresentable`, coordinator pattern       | `references/appkit-swiftui-hybrid.md`
Metal, `CAMetalLayer`, infinite canvas, WKWebView embedding                                | `references/advanced-rendering.md`
Embedding libghostty terminal surfaces                                                     | `references/libghostty-integration.md`
Tier-1 repos to clone and study                                                            | `references/reference-repos.md`
Swift concurrency pitfalls (split isolation, Task.detached, blocking async)                 | `references/swift-concurrency.md`
What NOT to do                                                                             | `references/anti-patterns.md`
Swift syntax from a TypeScript/Python lens                                                 | `references/swift-for-ts-devs.md`

## Top 10 anti-patterns (short form)

Full list with "do this instead" pointers: `references/anti-patterns.md`

1. **`NSPopover` for menu bar UI** — use `NSMenu`; popovers have dismissal bugs and don't feel native
2. **Pure SwiftUI for complex desktop apps** — missing APIs for multi-window, borderless windows, system tray; always hybrid at the shell
3. **Missing sandbox or notarization** — Gatekeeper quarantine on first launch; app refuses to run on fresh systems
4. **Large `NSOutlineView` without virtualization** — 10k+ items hang the UI; animations can't be disabled
5. **Hardcoded file paths instead of `NSOpenPanel`/bookmarks** — sandbox violations; fails on Mac App Store
6. **Ignoring `Task.isCancelled` in long-running work** — tasks don't auto-cancel; background work burns CPU/battery
7. **Custom undo instead of `NSUndoManager`** — users expect `Cmd+Z`; custom stacks are fragile
8. **Privileged ops in the main app process** — use an XPC helper for file-system, network, or system operations
9. **Force-unwrapping Apple APIs that return optional** (`MTLCreateSystemDefaultDevice()!`) — crash on older hardware/VMs
10. **Saving preferences straight to a plist in the bundle** — bundles are read-only on signed apps; use `UserDefaults` or app support directory

## Modern Swift defaults (Swift 6.1+, macOS 14+)

- **Default to `@MainActor`** on view controllers, view models, and anything touching UIKit/AppKit. Opt into parallelism explicitly via `nonisolated` or detached tasks.
- **Use `async`/`await`** over completion handlers. Avoid `Combine` for new code unless the API surface demands it.
- **Use `Observable` macro** (not `ObservableObject`) for SwiftUI view models on macOS 14+.
- **Use typed throws** (`func load() throws(LoadError)`) for domain errors where the caller can meaningfully discriminate.
- **Structured concurrency**: prefer `async let` and `TaskGroup` over `DispatchQueue`. Limit `DispatchQueue` to interop with C APIs that demand it.
- **Deployment target ≥ macOS 14** unless you have a concrete reason. macOS 14 unlocks `Observable`, `SwiftData`, `NavigationStack` for documents, and modern `SwiftUI` APIs.

## Project setup checklist

1. New Xcode project → macOS → App (or `swift package init --type executable` + `Package.swift` with `.macOS(.v14)` platform)
2. Set deployment target to macOS 14+
3. Configure signing: select your Apple Developer team; enable automatic signing for dev; enable App Sandbox entitlement if distributing via Mac App Store
4. Add `Info.plist` entries: `CFBundleIdentifier`, `LSApplicationCategoryType`, `NSHumanReadableCopyright`, and any `CFBundleDocumentTypes` for document apps
5. Wire up `NSApplicationDelegate` (even in SwiftUI apps via `@NSApplicationDelegateAdaptor`) for lifecycle hooks not exposed by SwiftUI's `App` protocol
6. Set up `OSLog` subsystem and categories early (`Logger(subsystem: "com.you.App", category: "...")`)
7. Set up Sparkle (for direct distribution) or App Store submission pipeline (for Mac App Store) — both require code signing and notarization. See `references/distribution.md`

## Key external resources

- [Apple HIG for macOS](https://developer.apple.com/design/human-interface-guidelines/macos) — the source of truth for native feel
- [Apple sample code catalog](https://developer.apple.com/documentation/) — filter by "macOS"
- [Hacking with macOS (Paul Hudson)](https://www.hackingwithswift.com/books/macos) — best narrative reference for `NSDocument`, `NSOutlineView`, menus
- [objc.io books](https://www.objc.io/books/) — *App Architecture*, *Advanced Swift*, *Thinking in SwiftUI* (still relevant for hybrid apps)
- [Sparkle documentation](https://sparkle-project.org/documentation/) — the canonical auto-update framework for direct distribution
- [Matt Massicotte's blog](https://www.massicotte.org/) — Swift concurrency and XPC
- Peter Steinberger — ["Code Signing and Notarization: Sparkle and Tears"](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears)
- WWDC sessions — search "macOS", "AppKit", "XPC", "SwiftData"

Tier-1 open-source repos to clone and study: `references/reference-repos.md`
