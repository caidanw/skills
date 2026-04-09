---
name: swift-reference-repos
description: "Curated production-grade Swift/AppKit reference repositories for macOS desktop app development. Covers: CodeEdit (22k stars, full IDE with NSSplitView, NSToolbar, sidebar+editor+inspector layout, custom view embedding, AppKit+SwiftUI hybrid), STTextView (1.3k stars, TextKit 2 custom NSView with plugin architecture, gutter views, cross-platform AppKit/UIKit), and Ghostty/Ghostling (30k stars, terminal emulator embedding via libghostty C API, Metal rendering, multi-threaded architecture). Also includes detailed WKWebView embedding patterns for canvas-style compositors. Use this skill when: building macOS desktop apps with AppKit, embedding WKWebView or custom NSViews into a canvas/compositor, working with NSSplitView or multi-pane layouts, building AppKit+SwiftUI hybrid architectures, creating custom NSView subclasses, embedding terminal emulators via libghostty, needing Swift↔JavaScript bridging via WKWebView, working with NSToolbar/NSWindow/NSViewController patterns, or needing to clone and study exemplary Swift desktop codebases. Also trigger when the user mentions 'clone a reference repo', 'AppKit patterns', 'WKWebView embedding', 'NSSplitView', 'desktop app architecture', or asks for macOS-native development patterns."
---

# Swift macOS Desktop App Reference Repositories

Three production-grade, MIT-licensed Swift repositories that serve as architectural references for building native macOS desktop applications. Focused on AppKit, custom view embedding, compositor-style layouts, and hybrid AppKit+SwiftUI patterns.

## Quick Reference

| Repo | Purpose | Stars | What It Teaches |
|------|---------|-------|-----------------|
| CodeEditApp/CodeEdit | Full macOS IDE | ~22k | NSSplitView, sidebar+editor+inspector, NSToolbar, custom view embedding, AppKit+SwiftUI hybrid |
| krzyzanowskim/STTextView | TextKit 2 text component | ~1.3k | Custom NSView subclass, plugin architecture, gutter/ruler, cross-platform AppKit+UIKit |
| ghostty-org/ghostty + ghostling | Terminal emulator + libghostty | ~30k | C library embedding in Swift, Metal rendering, multi-threaded terminal, AppKit surface lifecycle |

Plus: WKWebView embedding patterns for canvas-style compositors (see `references/wkwebview-embedding.md`).

---

## 1. CodeEdit — macOS Desktop IDE Architecture

**Clone:** `git clone --depth 1 https://github.com/CodeEditApp/CodeEdit.git`
**License:** MIT | **Language:** Swift | **Target:** macOS 13+

The single best open-source reference for building a complex macOS desktop app. 22k+ stars, active development, and a codebase that demonstrates nearly every AppKit pattern you'll need.

**Read:** `references/codeedit.md` for detailed source map and patterns.

**Key patterns this repo teaches:**
- **AppKit+SwiftUI hybrid architecture** — AppKit owns window lifecycle, toolbar, and split view; SwiftUI owns sidebar content, inspectors, settings
- **NSSplitView for multi-pane layouts** — Sidebar + editor area + inspector, with collapsible panes and drag handles
- **NSToolbar** — Programmatic toolbar with customizable items
- **Custom NSView embedding** — Embeds CodeEditTextView (a custom NSView) inside SwiftUI via NSViewRepresentable
- **NSHostingView / NSHostingController** — Embedding SwiftUI views inside AppKit containers
- **Window management** — NSWindowController, NSDocument-based architecture
- **Tree-sitter integration** — FFI to a C library for syntax highlighting (similar pattern to libghostty)
- **Tab management** — Custom tab bar implementation
- **File browser sidebar** — NSOutlineView-style recursive tree

### Related CodeEdit repos (study together):
- `CodeEditApp/CodeEditTextView` — Pure AppKit text view, NSView subclass, no SwiftUI
- `CodeEditApp/CodeEditSourceEditor` — Source editor wrapping CodeEditTextView with tree-sitter
- `CodeEditApp/CodeEditLanguages` — Tree-sitter grammar integration

---

## 2. STTextView — Custom NSView Component Patterns

**Clone:** `git clone --depth 1 https://github.com/krzyzanowskim/STTextView.git`
**License:** BSD-style | **Language:** Swift | **Target:** macOS 12+, iOS 16+

The definitive example of building a production-quality custom NSView subclass. Created as an NSTextView/UITextView replacement using TextKit 2, it demonstrates every pattern you need for building embeddable AppKit components.

**Read:** `references/sttextview.md` for detailed source map and patterns.

**Key patterns this repo teaches:**
- **Custom NSView subclass architecture** — Proper init, layout, drawing, event handling
- **Plugin system** — STPlugin protocol for extending view behavior without subclassing
- **Gutter/ruler views** — NSRulerView-style line number gutters alongside content
- **Cross-platform architecture** — Same API surface for AppKit and UIKit via platform-specific implementations sharing common code
- **TextKit 2** — NSTextLayoutManager, NSTextContentStorage, fragment-based layout
- **Coordinator pattern** — For bridging complex AppKit state into SwiftUI
- **SwiftUI wrapping** — How to wrap a complex AppKit view for SwiftUI consumption

---

## 3. Ghostty + Ghostling — Terminal Embedding & C Library Integration

**Clone:**
```bash
git clone --depth 1 https://github.com/ghostty-org/ghostty.git
git clone --depth 1 https://github.com/ghostty-org/ghostling.git
```
**License:** MIT | **Languages:** Zig (core), Swift (macOS app), C (API/demo)

The reference for embedding a high-performance C library into a macOS AppKit app. Ghostty's macOS frontend is a Swift/AppKit app that consumes the Zig-compiled libghostty via C API.

**Read:** `references/ghostty.md` for detailed source map and patterns.

**Key patterns these repos teach:**
- **C library consumption from Swift** — Bridging headers, C function calls, callback registration
- **NSView subclass hosting a render surface** — SurfaceView.swift wraps a CAMetalLayer-backed view
- **Multi-threaded view architecture** — IO thread + render thread per embedded view
- **AppKit event forwarding** — Keyboard and mouse events forwarded from NSView to C library
- **Metal rendering inside NSView** — CAMetalLayer setup, drawable lifecycle, frame synchronization
- **Ghostling (~600 lines of C)** — Minimal complete example of consuming the libghostty-vt C API

---

## 4. WKWebView Embedding Patterns

No single repo perfectly demonstrates WKWebView canvas embedding, so `references/wkwebview-embedding.md` synthesizes the best patterns from across the ecosystem.

**Read:** `references/wkwebview-embedding.md` for complete patterns.

**Key patterns covered:**
- **WKWebView as child NSView** — Creating and embedding in AppKit view hierarchies
- **Swift↔JavaScript bridge** — WKScriptMessageHandler for JS→Swift, evaluateJavaScript for Swift→JS
- **WKUserContentController** — Injecting scripts, message handlers, content rules
- **Multiple WKWebViews in a layout** — Process pooling, memory management, lifecycle
- **NSViewRepresentable wrapping** — Bridging WKWebView into SwiftUI
- **Web Inspector** — Enabling Safari Web Inspector for embedded WKWebViews
- **Custom URL schemes** — WKURLSchemeHandler for intercepting requests
- **Keyboard/focus management** — Handling first responder with embedded web views

---

## Agent Workflow: Cloning and Using References

```bash
# Clone only what you need
git clone --depth 1 https://github.com/CodeEditApp/CodeEdit.git /tmp/ref-codeedit
git clone --depth 1 https://github.com/krzyzanowskim/STTextView.git /tmp/ref-sttextview
git clone --depth 1 https://github.com/ghostty-org/ghostty.git /tmp/ref-ghostty
git clone --depth 1 https://github.com/ghostty-org/ghostling.git /tmp/ref-ghostling
```

Use `--depth 1` for shallow clones. Start with the Source Map in each reference doc to find the key files.

---

## Ecosystem: Other Repos Worth Knowing

| Repo | Stars | What It Shows |
|------|-------|---------------|
| `overtake/TelegramSwift` | ~5k | Massive production AppKit app — custom scroll views, animation, media embedding (GPL) |
| `Whisky-App/Whisky` | ~15k | SwiftUI macOS app wrapping a complex native subsystem (Wine) (GPL) |
| `HazAT/glimpse` | new | Native macOS micro-UI with WKWebView + bidirectional JSON messaging |
| `kfix/MacPin` | ~1k | Full WKWebView webapp container with NSTabViewController + JavaScriptCore bridge |
| `dagronf/DSFAppKitBuilder` | ~400 | SwiftUI-style DSL for building AppKit views programmatically |
| `dagronf/AppKitUI` | new | AppKit UI toolkit with previews, declarative layout |
| `AudioKit/Flow` | ~388 | SwiftUI node graph editor for flow-based UIs (MIT) |
| `microsoft/fluentui-apple` | ~950 | Microsoft's UIKit/AppKit component library (MIT) |
| `nicklockwood/SwiftFormat` | ~8k | Not UI, but exemplary Swift project structure and tooling |
| `danielsaidi/WebViewKit` | ~200 | Simple cross-platform WKWebView SwiftUI wrapper (MIT) |
