# Reference Repos: Production-Grade Swift macOS Apps

Curated open-source repos to clone and study when building a macOS desktop app in Swift. Each entry tells you what patterns it demonstrates and which files to read first.

Star counts drift — don't take exact numbers as current. Verify license and activity before adopting any dependency.

## How to use this list

```bash
# Shallow clone to read, not modify
git clone --depth 1 https://github.com/rxhanson/Rectangle.git /tmp/ref-rectangle
git clone --depth 1 https://github.com/coteditor/CotEditor.git /tmp/ref-coteditor
git clone --depth 1 https://github.com/CodeEditApp/CodeEdit.git /tmp/ref-codeedit
git clone --depth 1 https://github.com/jordanbaird/Ice.git /tmp/ref-ice
git clone --depth 1 https://github.com/exelban/stats.git /tmp/ref-stats
git clone --depth 1 https://github.com/XcodesOrg/XcodesApp.git /tmp/ref-xcodes
git clone --depth 1 https://github.com/ghostty-org/ghostty.git /tmp/ref-ghostty
git clone --depth 1 https://github.com/krzyzanowskim/STTextView.git /tmp/ref-sttextview
```

Read the source map in each entry below to jump straight to the key files.

## Tier 1: study deeply

### CodeEdit — macOS IDE Architecture

- **Repo:** [github.com/CodeEditApp/CodeEdit](https://github.com/CodeEditApp/CodeEdit)
- **License:** MIT
- **Target:** macOS 13+
- **Why:** The single best open-source reference for a complex macOS app. AppKit+SwiftUI hybrid, `NSSplitView`, `NSToolbar`, `NSOutlineView`, `NSDocument`, modular SPM packages, custom `NSView` embedding.

**Source map:**

```
CodeEdit/
├── CodeEdit/
│   ├── CodeEditApp.swift                 ← @main SwiftUI App
│   ├── AppDelegate.swift                 ← NSApplicationDelegate — menu, window mgmt
│   ├── WorkspaceDocument.swift           ← NSDocument subclass
│   ├── CodeEditWindowController.swift    ← NSWindowController
│   ├── SplitView/
│   │   ├── CodeEditSplitView.swift       ← Sidebar | editor | inspector NSSplitView
│   │   └── SplitViewItem.swift
│   └── Features/
│       ├── Editor/                       ← Editor area + tabs
│       ├── Navigator/                    ← Sidebar panels (files, search, git)
│       ├── InspectorSidebar/             ← Right-side inspector
│       ├── WindowCommands/
│       │   └── MainToolbar.swift         ← Programmatic NSToolbar
│       ├── Settings/                     ← Preferences window
│       └── StatusBar/
└── CodeEditModules/                      ← SPM packages
    └── Modules/
        ├── CodeEditSourceEditor/         ← Source editor wrapping CodeEditTextView
        ├── CodeEditTextView/             ← Pure AppKit text view (separate repo)
        └── CodeEditLanguages/            ← Tree-sitter grammars
```

**What to read first** (in order):
1. `AppDelegate.swift` — menu setup, activation policy
2. `CodeEditWindowController.swift` — `NSWindowController` + `NSWindow` setup
3. `SplitView/CodeEditSplitView.swift` — canonical three-pane `NSSplitView`
4. `Features/WindowCommands/MainToolbar.swift` — programmatic `NSToolbar`
5. `WorkspaceDocument.swift` — `NSDocument` lifecycle for project-style apps

**Patterns it teaches:**
- AppKit+SwiftUI hybrid where AppKit owns the shell and SwiftUI owns content panels
- `NSSplitViewItem.sidebar(...)` / `.contentList(...)` / `.inspector(...)` — the proper way to get collapse animations, snap points, and accessibility for free
- Modular SPM structure — each subsystem is its own Swift Package, developable and testable in isolation
- Tree-sitter FFI integration (similar pattern to libghostty)
- Embedding a custom `NSView` (the text editor) in SwiftUI via `NSViewRepresentable`

### STTextView — Custom NSView Patterns

- **Repo:** [github.com/krzyzanowskim/STTextView](https://github.com/krzyzanowskim/STTextView)
- **License:** BSD
- **Target:** macOS 12+, iOS 16+
- **Author:** Marcin Krzyzanowski
- **Why:** The definitive example of building a production custom `NSView` subclass. Created as an `NSTextView`/`UITextView` replacement on TextKit 2 after the author filed 20+ Apple Feedback reports on `NSTextView`. **Read it even if you're not building a text editor** — the architecture is the blueprint for any embeddable AppKit view component.

**Source map:**

```
Sources/
├── STTextViewCommon/              ← Shared protocols + data types
│   ├── STPlugin.swift             ← Plugin protocol
│   ├── STPluginContext.swift
│   └── STPluginEvents.swift
├── STTextViewAppKit/              ← macOS implementation
│   ├── STTextView.swift           ← START HERE: main NSView subclass
│   ├── STTextView+Gutter.swift    ← Line number gutter integration
│   ├── STTextView+Mouse.swift     ← Mouse event handling
│   ├── STTextView+Keyboard.swift  ← Key event handling
│   ├── STTextView+Scrolling.swift
│   ├── STTextView+DragDrop.swift
│   └── Gutter/
│       ├── STGutterView.swift     ← NSRulerView subclass
│       └── STGutterLineNumberCell.swift
├── STTextViewUIKit/               ← iOS UIView implementation (parallel structure)
└── STTextViewSwiftUI/             ← NSViewRepresentable + UIViewRepresentable wrappers
```

**What to read first:**
1. `STTextViewAppKit/STTextView.swift` — the full `NSView` subclass lifecycle
2. `STTextViewCommon/STPlugin.swift` — protocol-based plugin system
3. `Gutter/STGutterView.swift` — `NSRulerView` for sidebars attached to scrolling content
4. `STTextViewSwiftUI/TextViewUI.swift` — `NSViewRepresentable` with a coordinator

**Patterns it teaches:**
- Proper `NSView` subclass lifecycle (`commonInit`, `layout`, `draw`, first responder management)
- Protocol-based plugin architecture (prefer plugins over subclassing for extensibility)
- Cross-platform architecture via `STTextViewCommon` + per-platform implementations
- `NSRulerView` for gutter/ruler views attached to `NSScrollView`
- Clean `NSViewRepresentable` wrapping via a Coordinator

### Rectangle — Window Management Utility

- **Repo:** [github.com/rxhanson/Rectangle](https://github.com/rxhanson/Rectangle)
- **License:** MIT
- **Why:** The model menu-bar utility. Minimal UI, heavy system integration. Teaches `NSWindow` geometry math, global shortcut registration (MASShortcut), Sparkle auto-updates, and `UserDefaults`-driven configuration.

**What to read first:**
1. `Rectangle/AppDelegate.swift` — activation policy, menu bar status item
2. `Rectangle/WindowManager/` — window geometry calculations (multi-screen, spaces)
3. `Rectangle/Shortcuts/` — MASShortcut integration
4. `Rectangle/Settings/` — preferences window driven by `UserDefaults` + `@AppStorage`

**Patterns it teaches:**
- `LSUIElement = true` menu bar app (no dock icon)
- Global keyboard shortcut registration
- Multi-screen window geometry math
- Sparkle auto-update integration (read the `Sparkle/` integration code)
- `UserDefaults` + `@AppStorage` binding to SwiftUI preferences

### CotEditor — Document-Based Text Editor

- **Repo:** [github.com/coteditor/CotEditor](https://github.com/coteditor/CotEditor)
- **License:** Apache 2.0
- **Why:** Text editor done *right* on the classic `NSDocument` model. Demonstrates file coordination, autosave, versions, undo/redo via `NSUndoManager`, and a well-organized modular package layout.

**What to read first:**
1. `CotEditor/Sources/Document Window/DocumentController.swift`
2. `CotEditor/Sources/Document/Document.swift` — `NSDocument` subclass
3. `CotEditor/Sources/Document Window/Window/DocumentWindow.swift`
4. `Packages/EditorCore/` — SPM submodules: `TextEditing`, `FileEncoding`, `Syntax`

**Patterns it teaches:**
- Full `NSDocument` lifecycle (open, save, autosave, versions, revert, duplicate)
- `NSFileCoordinator` / `NSFilePresenter` for cooperating with other processes
- `NSUndoManager.registerUndo(withTarget:)` — action grouping and stack management
- Modular SPM structure with strict internal dependencies
- `NSTextView` customization without subclassing (via delegate and layout manager tricks)

### Xcodes.app — XPC Helper + Hybrid Architecture

- **Repo:** [github.com/XcodesOrg/XcodesApp](https://github.com/XcodesOrg/XcodesApp)
- **License:** MIT
- **Why:** The best open-source example of splitting privileged operations into an XPC helper. Also demonstrates Combine + SwiftUI + AppKit hybrid architecture, a multi-connection downloader, and the macOS security model for elevated operations.

**What to read first:**
1. `Xcodes/AppState.swift` — Combine-driven global state
2. `XPCServiceTarget/` — the privileged helper target
3. `Xcodes/Downloading/` — concurrent downloader

**Patterns it teaches:**
- XPC helper for operations that need elevated permissions or sandbox exceptions
- Combine + SwiftUI on macOS at production scale
- Concurrent HTTP downloads with resume support
- Keychain for credential storage
- App update integration via Sparkle

### Ghostty — C Library Integration + Metal Terminal

- **Repos:** [github.com/ghostty-org/ghostty](https://github.com/ghostty-org/ghostty), [github.com/ghostty-org/ghostling](https://github.com/ghostty-org/ghostling)
- **License:** MIT
- **Creator:** Mitchell Hashimoto
- **Why:** The reference for embedding a Zig/C library that owns rendering into an AppKit app. Swift consumes libghostty via a bridging header; the library owns Metal rendering and PTY management; the Swift app owns windowing and events.

**Source map (macOS app only — focus here for desktop patterns):**

```
ghostty/macos/Sources/
├── App.swift                          ← @main entry
├── AppDelegate.swift                  ← NSApplicationDelegate
└── Ghostty/
    ├── SurfaceView.swift              ← KEY: NSView hosting a terminal surface
    ├── SurfaceView+Keyboard.swift     ← AppKit keyboard events → C API
    ├── SurfaceView+Mouse.swift        ← AppKit mouse events → C API
    ├── TerminalController.swift       ← NSWindowController managing surfaces
    ├── TerminalView.swift             ← SwiftUI wrapper for SurfaceView
    └── Package.swift                  ← Swift types wrapping C API
```

**Patterns it teaches:**
- `NSView` hosting an external render surface (`CAMetalLayer` owned by a C library)
- AppKit event forwarding to C via bridging headers
- Multi-surface window management (tabs, splits) with per-surface threading
- See `libghostty-integration.md` for integration details

For libghostty embedding patterns specifically, read `libghostty-integration.md` in this skill.

### Ice — NSStatusItem Menu Bar Manager

- **Repo:** [github.com/jordanbaird/Ice](https://github.com/jordanbaird/Ice)
- **License:** MIT
- **Why:** A modern menu bar icon manager written in Swift. Teaches `NSStatusItem` in depth, drag-and-drop reordering, pasteboard-driven UI, and persistent ordering.

**Patterns it teaches:**
- `NSStatusBar` / `NSStatusItem` advanced usage (multiple items, dynamic updates)
- Drag-and-drop reordering via `NSPasteboardWriting`/`NSPasteboardReading`
- SwiftUI-based settings windows for a menu bar app
- Persisting user-arranged order across launches

### Stats — System Monitor Menu Bar App

- **Repo:** [github.com/exelban/stats](https://github.com/exelban/stats)
- **License:** MIT
- **Why:** Large-scale menu bar app with many data sources (CPU, GPU, memory, disk, network). Shows how to keep a menu-bar app responsive while doing continuous sampling.

**Patterns it teaches:**
- Multi-widget `NSStatusItem` composition
- IOKit usage for hardware stats
- Periodic sampling without blocking the UI
- Custom popover-alternative menu UIs that feel native

## Tier 2: notable, study for specific patterns

| Repo | License | Look here for |
|---|---|---|
| [IINA](https://github.com/iina/iina) | GPL-2.0 (**study only, can't copy**) | libmpv FFI, plugin system, Force Touch, Picture-in-Picture, Touch Bar integration |
| [SourceView-Swift](https://github.com/ooper-shlab/SourceView-Swift) | Apple sample | Canonical `NSOutlineView` + `NSTreeController` source-list |
| [kfix/MacPin](https://github.com/kfix/MacPin) | GPL | Full WKWebView webapp container with `NSTabViewController` and a JavaScriptCore bridge |
| [danielsaidi/WebViewKit](https://github.com/danielsaidi/WebViewKit) | MIT | Clean cross-platform `WKWebView` SwiftUI wrapper |
| [dagronf/DSFAppKitBuilder](https://github.com/dagronf/DSFAppKitBuilder) | MIT | SwiftUI-style DSL for building AppKit views programmatically |
| [AudioKit/Flow](https://github.com/AudioKit/Flow) | MIT | SwiftUI node graph editor (for flow-based UIs) |
| [microsoft/fluentui-apple](https://github.com/microsoft/fluentui-apple) | MIT | Microsoft's UIKit/AppKit component library |
| [nicklockwood/SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | MIT | Not UI — exemplary Swift project structure and tooling |
| [overtake/TelegramSwift](https://github.com/overtake/TelegramSwift) | GPL (**study only**) | Massive production AppKit app — custom scroll views, animations, media |

## Humans worth following

| Who | What they publish | Why |
|---|---|---|
| [Matt Massicotte](https://www.massicotte.org/) | Swift concurrency, XPC, editor infrastructure ([ChimeHQ](https://github.com/ChimeHQ)) | Wrote the Swift 6 migration guide; `AsyncXPCConnection` and related packages are the modern XPC patterns |
| Paul Hudson | [Hacking with macOS](https://www.hackingwithswift.com/books/macos) | Best narrative reference for `NSDocument`, `NSOutlineView`, menus, basic AppKit patterns |
| [Peter Steinberger](https://steipete.me/) | [Code Signing and Notarization: Sparkle and Tears](https://steipete.me/posts/2025/code-signing-and-notarization-sparkle-and-tears) | The most honest writeup of production code signing pain |
| [Ole Begemann](https://oleb.net/) | Blog posts on SwiftUI + AppKit interop, advanced layouts | Deeply researched posts that go further than the WWDC happy path |
| [Krzysztof Zabłocki](https://github.com/krzysztofzablocki) | [Sourcery](https://github.com/krzysztofzablocki/Sourcery) | Code generation for `Hashable`, `Equatable`, mocks — reduces boilerplate |
| [Marcin Krzyzanowski](https://github.com/krzyzanowskim) | STTextView | Swift `NSView` subclass master class |
| Helge Heß ([@helje5](https://github.com/helje5)) | Declarative UI patterns, macros | Lots of small, well-argued experiments in Swift UI DSLs |

## Reading order for a new macOS app

1. **CodeEdit** — canonical shell architecture (`NSSplitView`, toolbar, document)
2. **Rectangle** — menu bar + preferences + Sparkle + global shortcuts
3. **CotEditor** — if you're building a document-based app, read `Document.swift` before writing anything
4. **Xcodes.app** — if you need privileged operations, read the XPC target first
5. **STTextView** — if you're building any custom `NSView` subclass (text editor, canvas, inspector)
6. **Ghostty macOS app** — if you need a custom render surface owned by a library
7. **Ice / Stats** — if it's a menu bar app, either of these is a better starting point than CodeEdit

Don't read all of any of these cover to cover. Use the source maps above to jump to the files that match your current question, then move on.
