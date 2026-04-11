# User Interaction: Undo, Drag-and-Drop, Pasteboard, Shortcuts, Accessibility

This reference covers the user-facing plumbing of a macOS app: `NSUndoManager` for undo/redo, `NSPasteboard` for clipboard and custom types, AppKit and SwiftUI drag-and-drop, `NSOpenPanel`/`NSSavePanel` in async form, keyboard shortcuts at the menu/view/global levels, and `NSAccessibility` for VoiceOver. For document-level integration see `document-apps.md`; for app-wide Intents see `system-integration.md`.

## Table of contents

- [NSUndoManager](#nsundomanager)
- [Undo and NSDocument](#undo-and-nsdocument)
- [NSPasteboard basics](#nspasteboard-basics)
- [Custom pasteboard types](#custom-pasteboard-types)
- [Drag and drop: the source side](#drag-and-drop-the-source-side)
- [Drag and drop: the destination side](#drag-and-drop-the-destination-side)
- [SwiftUI drag and drop](#swiftui-drag-and-drop)
- [NSOpenPanel and NSSavePanel](#nsopenpanel-and-nssavepanel)
- [Security-scoped bookmarks](#security-scoped-bookmarks)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [First responder and key equivalents](#first-responder-and-key-equivalents)
- [Accessibility (NSAccessibility)](#accessibility-nsaccessibility)
- [Testing accessibility](#testing-accessibility)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## NSUndoManager

Every user action that changes model state should be undoable. `NSDocument` exposes a ready-to-use `undoManager`; plain AppKit objects can own one themselves. The standard pattern: capture the old value, apply the new, then register an inverse that calls the same setter.

```swift
@MainActor
final class Model {
    private(set) var text: String = ""
    let undoManager = UndoManager()

    func setText(_ new: String) {
        let old = text
        text = new
        // Registering an inverse that calls the same setter makes redo work for
        // free: when the user undoes, the manager runs this closure, which itself
        // registers *another* inverse — that becomes the redo entry.
        undoManager.registerUndo(withTarget: self) { target in
            target.setText(old)
        }
        undoManager.setActionName("Change Text")
    }
}
```

The recursion is intentional. Because `registerUndo` called inside an undo operation becomes a redo registration, a single symmetric setter covers both directions. `setActionName` is what populates the "Undo Change Text" / "Redo Change Text" menu item title; set it on every registration or the user sees a bare "Undo".

Group related mutations with `beginUndoGrouping` / `endUndoGrouping` so a single user gesture undoes as one step:

```swift
func applyFormatting(_ formatting: Formatting, to range: NSRange) {
    undoManager.beginUndoGrouping()
    defer { undoManager.endUndoGrouping() }
    setFont(formatting.font, in: range)
    setColor(formatting.color, in: range)
    setWeight(formatting.weight, in: range)
}
```

Cap stack depth with `undoManager.levelsOfUndo = 50` when the model is large (each entry captures state by closure, and unbounded history can balloon memory). `0` means unlimited, which is the default.

## Undo and NSDocument

`NSDocument` wires its `undoManager` into the window and menu automatically — call `registerUndo` against the document or its model and `Cmd+Z` / `Cmd+Shift+Z` work with no extra plumbing. Dirty tracking is automatic too: a registered undo marks the document edited, and undoing back to saved state clears it. See `document-apps.md`.

## NSPasteboard basics

The macOS clipboard is `NSPasteboard.general`. Writing is a two-step dance: clear, then set.

```swift
let pb = NSPasteboard.general
pb.clearContents()  // Mandatory — without this, setString appends nothing.
pb.setString("hello", forType: .string)

if let text = pb.string(forType: .string) {
    // ...
}
```

`clearContents()` is not optional. Skip it and the previous owner stays in place; `setString` silently fails on some types. Pasteboard "types" are UTIs expressed as `NSPasteboard.PasteboardType`: `.string`, `.fileURL`, `.tiff`, `.pdf`, `.rtf`, `.html`, or a custom identifier like `NSPasteboard.PasteboardType("com.example.myapp.shape")`.

## Custom pasteboard types

To round-trip a model through the clipboard or a drag session, declare a custom UTI in `Info.plist` under `UTExportedTypeDeclarations` and conform the type to `NSPasteboardWriting` and `NSPasteboardReading`.

```swift
final class Shape: NSObject, NSPasteboardWriting, NSPasteboardReading, Codable {
    let id: UUID
    var kind: String
    var frame: CGRect

    init(id: UUID = UUID(), kind: String, frame: CGRect) {
        self.id = id; self.kind = kind; self.frame = frame
    }

    static let pbType = NSPasteboard.PasteboardType("com.example.myapp.shape")

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] { [Shape.pbType] }
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] { [pbType] }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        type == Shape.pbType ? try? JSONEncoder().encode(self) : nil
    }

    required convenience init?(pasteboardPropertyList propertyList: Any,
                               ofType type: NSPasteboard.PasteboardType) {
        guard type == Shape.pbType, let data = propertyList as? Data,
              let decoded = try? JSONDecoder().decode(Shape.self, from: data) else { return nil }
        self.init(id: decoded.id, kind: decoded.kind, frame: decoded.frame)
    }
}
```

`pb.writeObjects([shape])` and `pb.readObjects(forClasses: [Shape.self])` then work, and the same type drops into a drag session with no extra code.

## Drag and drop: the source side

An `NSView` becomes a drag source by starting a session in response to a drag gesture. The idiomatic path overrides `mouseDragged(with:)` to begin the session after the pointer has moved past a slop threshold.

```swift
final class ShapeSourceView: NSView, NSDraggingSource {
    var shape: Shape?

    override func mouseDragged(with event: NSEvent) {
        guard let shape else { return }
        let item = NSDraggingItem(pasteboardWriter: shape)
        item.setDraggingFrame(bounds, contents: snapshotImage())
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? [.move, .copy] : .copy
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        if operation == .move { shape = nil }
    }

    private func snapshotImage() -> NSImage { /* cacheDisplay into an NSImage */ NSImage() }
}
```

`NSDraggingSource` tells the source which operations are legal and when the drag ended. Return different masks for `.withinApplication` and `.outsideApplication` to allow move inside the app but only copy outside.

## Drag and drop: the destination side

A destination registers for the types it accepts and implements `draggingEntered(_:)` (show a drop hint), `draggingUpdated(_:)` (current operation), and `performDragOperation(_:)` (commit).

```swift
final class FileDropView: NSView {
    var onDrop: (([URL]) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self]) ? .copy : []
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return false
        }
        onDrop?(urls)
        return true
    }
}
```

Return `[]` from `draggingEntered` to refuse the drop — the cursor updates immediately. Return `false` from `performDragOperation` to animate the drag image back to the source.

## SwiftUI drag and drop

SwiftUI wraps the same machinery with `.draggable()` and `.dropDestination(for:action:)`. Both sides must conform to `Transferable`.

```swift
struct Canvas: View {
    @State private var shapes: [Shape] = []
    let palette: [Shape]

    var body: some View {
        HStack {
            ForEach(palette, id: \.id) { shape in
                RoundedRectangle(cornerRadius: 8).fill(.blue)
                    .frame(width: 80, height: 80)
                    .draggable(shape)  // Shape must be Transferable
            }
            Rectangle().fill(.gray.opacity(0.1))
                .dropDestination(for: Shape.self) { dropped, _ in
                    shapes.append(contentsOf: dropped)
                    return true
                }
        }
    }
}
```

SwiftUI drag-and-drop handles most cases but is less flexible than AppKit — custom drag images, mixed operations, and fine-grained mouse event control still require dropping to `NSViewRepresentable`. A SwiftUI `.draggable()` source can land in an AppKit `registerForDraggedTypes` destination as long as the pasteboard type lines up.

## NSOpenPanel and NSSavePanel

`standard-ui.md` covers the basics; this section focuses on the parameters you actually tune. The common knobs:

| Property                    | Effect                                                          |
| ---                         | ---                                                             |
| `allowedContentTypes`       | `[UTType]` — filter files shown in the open panel               |
| `allowsMultipleSelection`   | Open panel can return more than one URL                         |
| `canChooseDirectories`      | Allow picking folders                                           |
| `canChooseFiles`            | Allow picking files (set both for "either")                     |
| `canCreateDirectories`      | Show the "New Folder" button                                    |
| `message`                   | Descriptive text at the top of the panel                        |
| `prompt`                    | Custom label for the confirm button ("Import" instead of "Open") |
| `nameFieldStringValue`      | Save panel: suggested filename                                  |
| `directoryURL`              | Initial directory                                               |

Prefer the async `begin()` API so panel presentation composes with structured concurrency:

```swift
@MainActor
func pickFiles() async -> [URL]? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf, .png]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.prompt = "Import"
    guard await panel.begin() == .OK else { return nil }
    return panel.urls
}
```

`begin()` returning an `NSApplication.ModalResponse` is the async-capable form; use `beginSheetModal(for:)` to attach the panel to a specific window as a true sheet.

## Security-scoped bookmarks

A sandboxed app only retains access to URLs the user explicitly picks, and only for the current launch. To reopen a file later you must save a security-scoped bookmark and resolve it on relaunch. See `document-apps.md` for the full pattern including `startAccessingSecurityScopedResource()` and stale-bookmark handling.

## Keyboard shortcuts

Three layers, picked by scope.

### Menu key equivalents

Preferred for any command reachable from the main menu. The shortcut dispatches through the responder chain, so validation and enablement come free via `validateMenuItem(_:)`.

```swift
let item = NSMenuItem(title: "Export…",
                     action: #selector(AppDelegate.exportDocument(_:)),
                     keyEquivalent: "e")
item.keyEquivalentModifierMask = [.command, .shift]
fileMenu.addItem(item)
```

Lowercase letters are shift-free; use an uppercase letter or add `.shift` explicitly for shifted shortcuts. Avoid shortcuts Apple reserves (see the HIG keyboard shortcut list).

### SwiftUI keyboard shortcuts

Attach `.keyboardShortcut(_:modifiers:)` to a button, menu command, or any view that accepts it. Works inside SwiftUI menu commands and is the shortest path in a hybrid app.

```swift
Button("Save") { save() }
    .keyboardShortcut("s", modifiers: .command)

CommandGroup(replacing: .saveItem) {
    Button("Save") { save() }
        .keyboardShortcut("s", modifiers: .command)
}
```

### Global shortcuts

System-wide hotkeys that fire even when the app is inactive (menu bar utilities, quick-capture tools). The long-running BSD-licensed option is [MASShortcut](https://github.com/shpakovski/MASShortcut) — verified BSD 2-clause; check its current state before adopting as it has seen sparse maintenance in recent years. A minimal registration:

```swift
import MASShortcut

let key = "GlobalShowHotkey"
MASShortcutBinder.shared().bindShortcut(withDefaultsKey: key, toAction: {
    AppController.shared.togglePanel()
})
```

For truly raw system-wide capture you can fall back to `CGEventTap` with an `eventMask` and handler, but event taps require accessibility permissions and are harder to get right — only reach for them when a framework can't.

## First responder and key equivalents

View-level shortcuts that don't belong in a menu go through `performKeyEquivalent(with:)`. AppKit offers the event to every view in the responder chain before the main menu gets a shot, so a content view can claim a key combo before the menu sees it.

```swift
override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "k" {
        showQuickOpen()
        return true
    }
    return super.performKeyEquivalent(with: event)
}
```

Return `true` to claim the event; `false` lets AppKit continue the chain. Hybrid apps have subtle responder-chain quirks around `NSHostingView` — see `appkit-swiftui-hybrid.md` for the handoff rules.

## Accessibility (NSAccessibility)

Standard `NSButton`, `NSTextField`, `NSTableView`, and SwiftUI controls already handle VoiceOver. Custom `NSView` subclasses are the usual blind spots — VoiceOver sees them as an opaque blob unless you implement the protocol. A custom interactive view needs at minimum:

- `isAccessibilityElement` — return `true` so it shows up as a leaf
- `accessibilityLabel()` — the spoken name
- `accessibilityRole()` — what kind of thing it is (`.button`, `.image`, `.slider`, ...)
- `accessibilityValue()` — the current value for dynamic controls
- `accessibilityPerformPress()` — the default action for a button-like element

```swift
final class IconButton: NSView {
    var title: String = ""
    var onPress: () -> Void = {}

    override func mouseUp(with event: NSEvent) { onPress() }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { title }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
```

For composite controls, expose children via `accessibilityChildren()` and return `false` from `isAccessibilityElement` on the parent so VoiceOver treats it as a group. Dynamic content should update `accessibilityValue()` and post an `NSAccessibility.Notification.valueChanged` so VoiceOver re-announces.

## Testing accessibility

Turn on VoiceOver with `Cmd+F5` (or System Settings > Accessibility > VoiceOver) and navigate with `Ctrl+Option+Arrow` — every interactive element should speak. Xcode's **Accessibility Inspector** (Xcode > Open Developer Tool > Accessibility Inspector) exposes the tree, label, role, and value for any element under the pointer, and runs a basic audit. Apple's **Accessibility Audit API** (`XCUIApplication.performAccessibilityAudit`) runs automated checks in XCUITest targets — wire it into a UI test to catch regressions.

## Common pitfalls

- **Forgetting `clearContents()` before a pasteboard write.** The write silently fails or the previous owner's data hangs around — seen as "copy is broken, paste is stale".
- **Registering undo inside a `didSet` observer.** The undo invocation sets the property, which triggers `didSet`, which registers another undo — infinite recursion. Use an explicit setter method.
- **Custom `NSView` with no accessibility implementation.** VoiceOver announces "group" or skips it. Implement the protocol if interactive; override `isAccessibilityElement` to return `false` if decorative.
- **Legacy `NSString` pasteboard type constants** (`NSStringPboardType`) instead of UTI-based `NSPasteboard.PasteboardType.string`. The old names still compile but miss cross-app type coercion.
- **Global-shortcut frameworks that break on new macOS versions.** Event-handling APIs and permission prompts shift between releases; pin the version, test against the macOS you ship for, keep an `NSEvent.addLocalMonitorForEvents` fallback for in-app capture.
- **Forgetting `NSApp.presentationOptions` in fullscreen/kiosk modes.** `[.disableProcessSwitching, .hideDock, .autoHideMenuBar]` is required to block `Cmd+Tab`; first-responder tricks alone won't stop the OS switcher.

## References

- **Rectangle** (tier-1 list) — production MASShortcut integration and global shortcut UX
- **Ice** — drag-and-drop reordering in the menu bar; sets the bar for source/destination polish
- **CotEditor** — `NSUndoManager` wired through a real text editor with grouped edits and action names
- `document-apps.md` — document-level undo integration and security-scoped bookmarks
- `anti-patterns.md` — pasteboard and UTI gotchas including legacy `NSPasteboardTypeString` constants
- `system-integration.md` — app-level shortcuts and intents via `AppIntent` / Shortcuts
- `appkit-swiftui-hybrid.md` — responder chain caveats when mixing `NSHostingView` with AppKit
- Apple HIG — keyboard shortcut and accessibility chapters (reserved shortcuts, role guidelines)
