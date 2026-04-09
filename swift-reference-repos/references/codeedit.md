# CodeEdit — macOS Desktop IDE Architecture

**Repo:** `https://github.com/CodeEditApp/CodeEdit.git`
**License:** MIT
**Language:** Swift (100%)
**Target:** macOS 13+
**Stars:** ~22,700
**Architecture:** AppKit + SwiftUI hybrid

## What This Repo Is

CodeEdit is a native macOS code editor / IDE built entirely in Swift. It's the most complete open-source example of a production macOS desktop app using the AppKit+SwiftUI hybrid pattern. The codebase demonstrates virtually every AppKit desktop pattern: NSSplitView, NSToolbar, NSOutlineView (file trees), custom view embedding, tab management, window lifecycle, document-based app architecture, and tree-sitter FFI integration.

## Source Map — Read These First

```
CodeEdit/
├── CodeEdit/
│   ├── CodeEditApp.swift                    ← App entry point (SwiftUI @main App)
│   ├── AppDelegate.swift                    ← NSApplicationDelegate — window management, menu setup
│   │
│   ├── Features/
│   │   ├── Editor/                          ← CORE: Editor area with tabs + source editor
│   │   │   ├── EditorAreaView.swift         ← SwiftUI view for the editor pane
│   │   │   ├── EditorTabView.swift          ← Custom tab bar implementation
│   │   │   └── EditorAreaController.swift   ← Manages editor lifecycle
│   │   │
│   │   ├── Navigator/                       ← Sidebar file tree + search + source control
│   │   │   ├── NavigatorSidebar.swift       ← SwiftUI sidebar with switchable panels
│   │   │   └── ProjectNavigator/            ← File browser (recursive tree)
│   │   │
│   │   ├── InspectorSidebar/                ← Right-side inspector panel
│   │   │   └── InspectorSidebarView.swift   ← Contextual info panel
│   │   │
│   │   ├── WindowCommands/                  ← NSToolbar + menu commands
│   │   │   ├── MainToolbar.swift            ← Programmatic NSToolbar
│   │   │   └── ToolbarCommands.swift        ← Menu bar integration
│   │   │
│   │   ├── Settings/                        ← Preferences/Settings window
│   │   │   └── SettingsView.swift           ← SwiftUI settings panels
│   │   │
│   │   ├── StatusBar/                       ← Bottom status bar
│   │   ├── Terminal/                        ← Integrated terminal
│   │   ├── Git/                             ← Git integration
│   │   └── Search/                          ← Find & replace
│   │
│   ├── WorkspaceDocument.swift              ← NSDocument subclass — represents open project
│   ├── CodeEditWindowController.swift       ← NSWindowController — manages the workspace window
│   └── SplitView/                           ← NSSplitView configuration
│       ├── CodeEditSplitView.swift          ← Core split view (sidebar | editor | inspector)
│       └── SplitViewItem.swift              ← Individual pane configuration
│
├── CodeEditModules/                         ← SPM packages for modular architecture
│   ├── Modules/
│   │   ├── CodeEditSourceEditor/            ← Source editor component (separate repo)
│   │   ├── CodeEditTextView/                ← Pure AppKit text view (separate repo)
│   │   ├── CodeEditLanguages/               ← Tree-sitter grammars
│   │   └── ...
│   └── Package.swift
│
└── CodeEdit.xcodeproj
```

## Key Architectural Patterns

### Pattern 1: AppKit+SwiftUI Hybrid (The CodeEdit Way)

CodeEdit's architecture is the canonical example of how to build a modern macOS app:

```
AppKit Layer (outer shell):
├── NSApplication + NSApplicationDelegate (AppDelegate.swift)
├── NSWindow + NSWindowController (CodeEditWindowController.swift)
├── NSSplitView (CodeEditSplitView.swift)
├── NSToolbar (MainToolbar.swift)
└── NSDocument (WorkspaceDocument.swift)

SwiftUI Layer (inner content):
├── Sidebar panels (NavigatorSidebar.swift)
├── Inspector panels (InspectorSidebarView.swift)
├── Settings window (SettingsView.swift)
├── Status bar (StatusBarView.swift)
└── Tab bar content

Custom AppKit Views (embedded performance-critical):
├── CodeEditTextView (NSView subclass — the actual text editor)
└── Terminal view (NSView for terminal embedding)
```

**The rule:** AppKit owns the structural shell (windows, split views, toolbars). SwiftUI owns the content panels. Performance-critical views (text editing, terminal) are custom NSView subclasses embedded via NSViewRepresentable.

### Pattern 2: NSSplitView Three-Pane Layout

The classic macOS IDE layout: sidebar | editor | inspector. CodeEdit implements this with NSSplitView:

```swift
// Conceptual — study CodeEditSplitView.swift for the real implementation
let splitView = NSSplitView()
splitView.isVertical = true
splitView.dividerStyle = .thin

// Left: Navigator sidebar (collapsible)
let navigator = NSSplitViewItem(sidebarWithViewController: navigatorVC)
navigator.minimumThickness = 200
navigator.canCollapse = true

// Center: Editor area (non-collapsible)
let editor = NSSplitViewItem(contentListWithViewController: editorVC)

// Right: Inspector (collapsible)
let inspector = NSSplitViewItem(inspectorWithViewController: inspectorVC)
inspector.minimumThickness = 200
inspector.canCollapse = true

splitView.addArrangedSubview(navigator)
splitView.addArrangedSubview(editor)
splitView.addArrangedSubview(inspector)
```

Key takeaway: Use `NSSplitViewItem` convenience types (`.sidebarWithViewController`, `.contentListWithViewController`, `.inspectorWithViewController`) for proper AppKit behavior with collapse animations, snap-to guides, and accessibility.

### Pattern 3: NSDocument + NSWindowController

CodeEdit uses the document-based app pattern where each workspace is a `WorkspaceDocument`:

```
User opens folder
  → WorkspaceDocument created (NSDocument subclass)
    → CodeEditWindowController created (NSWindowController)
      → NSWindow with NSSplitView
        → Navigator, Editor, Inspector panels
```

This gives you: undo/redo per document, multiple windows, Spotlight integration, recent documents, and standard macOS window management for free.

### Pattern 4: Embedding Custom NSViews in SwiftUI

The editor area uses a custom NSView (CodeEditTextView) embedded in SwiftUI:

```swift
struct SourceEditorView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CodeEditTextView.scrollableTextView()
        let textView = scrollView.documentView as! CodeEditTextView
        textView.delegate = context.coordinator
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! CodeEditTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
}
```

### Pattern 5: NSToolbar (Programmatic)

CodeEdit builds its toolbar entirely in code (no storyboard):

```swift
class MainToolbar: NSToolbar, NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleNavigator, .flexibleSpace, .runButton, .flexibleSpace, .toggleInspector]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch identifier {
        case .toggleNavigator:
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)
            item.action = #selector(toggleNavigator)
            return item
        // ...
        }
    }
}
```

### Pattern 6: Modular SPM Architecture

CodeEdit splits functionality into SPM packages:
- `CodeEditTextView` — The pure AppKit text view
- `CodeEditSourceEditor` — Source editor with syntax highlighting
- `CodeEditLanguages` — Tree-sitter grammar definitions
- Each can be developed, tested, and versioned independently

## Adapting for Your Use Case

### Building a desktop app with embedded views (like WKWebView in a canvas):
1. Study `CodeEditSplitView.swift` for the three-pane NSSplitView layout
2. Study `EditorAreaView.swift` for how SwiftUI hosts the editor content
3. Study the NSViewRepresentable pattern in the source editor for embedding custom NSViews
4. Replace the text editor with your WKWebView or canvas view

### Building a window controller:
1. Study `CodeEditWindowController.swift` for NSWindowController patterns
2. Study `WorkspaceDocument.swift` for NSDocument lifecycle

### Building a toolbar:
1. Study `MainToolbar.swift` for programmatic NSToolbar
