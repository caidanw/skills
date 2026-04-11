# Document-based Apps: `NSDocument`, `FileDocument`, File Coordination, Autosave

This reference covers how to build document-based macOS apps: choosing between `NSDocument` and `FileDocument`, wiring up the lifecycle, registering document types, and integrating autosave, versions, file coordination, and undo. Undo internals live in `user-interaction.md`; sandbox entitlements live in `distribution.md`; window geometry lives in `windows-and-geometry.md`.

## Table of contents

- [Two document models](#two-document-models)
- [`NSDocument` lifecycle](#nsdocument-lifecycle)
- [Minimal `NSDocument` subclass](#minimal-nsdocument-subclass)
- [`FileDocument` minimal example](#filedocument-minimal-example)
- [Document types in Info.plist](#document-types-in-infoplist)
- [Autosave](#autosave)
- [Versions (Time Machine for documents)](#versions-time-machine-for-documents)
- [`NSFileCoordinator` and `NSFilePresenter`](#nsfilecoordinator-and-nsfilepresenter)
- [Undo/redo integration with `NSUndoManager`](#undoredo-integration-with-nsundomanager)
- [`NSDocumentController`](#nsdocumentcontroller)
- [Multi-window per document](#multi-window-per-document)
- [Security-scoped bookmarks](#security-scoped-bookmarks)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## Two document models

macOS exposes two parallel document systems. Pick based on the shape of your app, not novelty.

Feature                                       | `NSDocument` (AppKit)            | `FileDocument` / `ReferenceFileDocument` (SwiftUI)
---                                            | ---                              | ---
Undo/redo via `NSUndoManager`                  | Built in                         | Manual wiring through `UndoManager` environment value
Autosave in place                              | Yes (override `autosavesInPlace`) | Yes (automatic in `DocumentGroup`)
Autosave elsewhere / drafts                    | Yes (`autosavesDrafts`)          | Limited
Versions (version browser, revert)             | Yes (automatic)                  | Yes (inherited from autosave)
`NSFileCoordinator` / `NSFilePresenter`        | Integrated automatically         | Integrated but less configurable
Multi-window per document                      | Multiple `NSWindowController`s   | Not supported directly
Custom save panels / accessory views           | Override `prepareSavePanel(_:)` | Not available
Package documents (file wrappers with assets)  | Full `FileWrapper` access        | `FileWrapper` supported
Thread isolation                                | `@MainActor` by default          | `@MainActor` by default
Setup complexity                                | Higher (subclass + XIB/code)     | Lower (value type + scene)

**Recommendation:** Use `NSDocument` for non-trivial document apps — anything with custom toolbars, multiple windows per document, complex save panels, package formats, or heavy undo stacks (CotEditor, CodeEdit, Xcode, Pages). Use `FileDocument` for simple single-file editors where SwiftUI's `DocumentGroup` gives you the whole shell for free (notes, plain-text editors, markdown viewers).

## `NSDocument` lifecycle

```
  New doc ─────────► init()
  Open file ───────► read(from:ofType:)         load bytes from disk
                     │
                     ▼
                     makeWindowControllers()    attach UI
                     │
                     ▼
                     user edits                 updateChangeCount(.changeDone)
                     │                          undoManager?.registerUndo(...)
                     ├──► autosave tick ──► autosaveDocument(_:)  silent write
                     ├──► Cmd+S / Save As ─► save(_:) → data(ofType:)
                     ▼
                     canClose(...) → close      guard unsaved changes
```

Key methods to override:

- `init()` — new untitled document; set initial model state.
- `read(from:ofType:)` — parse file contents. Called on open.
- `data(ofType:)` — serialize current state. Called on save and autosave.
- `write(to:ofType:)` — use instead of `data(ofType:)` for package documents (`FileWrapper`).
- `makeWindowControllers()` — create window controllers and call `addWindowController(_:)`.
- `save(_:)` — usually not overridden; override `data(ofType:)` instead.
- `autosaveDocument(_:)` — rarely overridden; macOS calls it on a timer when dirty.
- `canClose(withDelegate:shouldClose:contextInfo:)` — override only to insert custom confirmation before the standard "save changes" sheet.

## Minimal `NSDocument` subclass

```swift
import AppKit

final class TextDocument: NSDocument {
    // Model state lives on the document. Main-actor isolated by default.
    var text: String = ""

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let id = NSStoryboard.SceneIdentifier("DocumentWindowController")
        guard let controller = storyboard.instantiateController(
            withIdentifier: id) as? NSWindowController else { return }
        addWindowController(controller)
        // Pass the document model into the root view controller here.
    }

    override func data(ofType typeName: String) throws -> Data {
        // Called on save and autosave. Keep fast; for large documents, snapshot
        // the model on the main actor and encode on a background task.
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        text = string  // Reads don't dirty the document — no updateChangeCount.
    }
}
```

Register the class in `Info.plist` via `NSDocumentClass` on the matching `CFBundleDocumentTypes` entry (below).

## `FileDocument` minimal example

```swift
import SwiftUI
import UniformTypeIdentifiers

struct NoteDocument: FileDocument {
    // Content types this document can open and save.
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

@main
struct NotesApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: NoteDocument()) { file in
            TextEditor(text: file.$document.text)
        }
    }
}
```

`DocumentGroup` handles the whole lifecycle — new/open/save/autosave/recents — automatically. For undo that survives document close, switch to `ReferenceFileDocument` so the model is a reference type.

## Document types in Info.plist

Register each file type in `CFBundleDocumentTypes` so the app appears in Finder's "Open With", accepts drops on the dock icon, and receives launch-with-file events.

```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Plain Text Document</string>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>LSHandlerRank</key>
    <string>Alternate</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>public.plain-text</string>
      <string>public.utf8-plain-text</string>
    </array>
    <key>NSDocumentClass</key>
    <string>$(PRODUCT_MODULE_NAME).TextDocument</string>
  </dict>
</array>
```

- `CFBundleTypeRole` — `Editor` (read + write), `Viewer` (read only), or `None`.
- `LSHandlerRank` — `Owner` claims the type system-wide (use for your own custom UTIs); `Alternate` shows up in "Open With" alongside other apps (use for shared types like `.txt`, `.md`). Using `Owner` on a common type will steal it from other apps on first launch — don't.
- `LSItemContentTypes` — UTIs, not extensions. Custom types must also be declared in `UTExportedTypeDeclarations` or `UTImportedTypeDeclarations`. Verify UTI strings against the current SDK.

## Autosave

- `class var autosavesInPlace: Bool` — when `true` (the modern default), macOS autosaves silently every few seconds and on deactivate/quit. `Cmd+S` becomes a visual confirmation; `Save As…` is the only path that shows a panel.
- `class var autosavesDrafts: Bool` — when `true`, new untitled documents also autosave to a draft location so they survive crashes before first save. Enable alongside `autosavesInPlace`.
- `hasUnautosavedChanges` / `isDocumentEdited` — query state; the title bar edited dot is automatic.
- `updateChangeCount(_:)` — call with `.changeDone` after each user-visible mutation. Undo registrations do this for you.

Autosaves call the same `data(ofType:)` / `write(to:ofType:)` path as explicit saves. Keep serialization under ~100ms for typical documents or autosave will hitch the UI — snapshot the model up front and do heavy encoding off the main actor.

## Versions (Time Machine for documents)

When `autosavesInPlace` is `true`, macOS records a version on every save and the user gets:

- **Revert To… → Browse All Versions** — a Time Machine-style UI for diffing and restoring past versions.
- `File → Revert to Saved` — rolls back unsaved changes to the last on-disk version. Override `revertToSaved(_:)` only if you need to clean up transient state.
- Versions live in `.DocumentRevisions-V100` on the same volume and follow the file on copy/rename inside APFS.

Mostly free. The one snag: package documents — rewriting a full `FileWrapper` on every save is expensive. Use `FileWrapper`'s child replacement APIs to update only changed children.

## `NSFileCoordinator` and `NSFilePresenter`

File coordinators serialize reads and writes across processes so Finder, Dropbox, iCloud Drive, and other apps see a consistent view of your files. Presenters subscribe to coordinated changes on files you're watching (the open document, a workspace folder, a config sidecar).

`NSDocument` plumbs both in automatically — you do not call the coordinator by hand to save the document itself. You do need it for non-document file access from inside a document app: sidecar files, workspace directory scans, imports the document references.

```swift
import Foundation

func readSidecar(at url: URL) throws -> Data {
    let coordinator = NSFileCoordinator(filePresenter: nil)
    var coordinatorError: NSError?
    var result: Data?
    var readError: Error?

    coordinator.coordinate(readingItemAt: url,
                           options: .withoutChanges,
                           error: &coordinatorError) { readURL in
        do {
            result = try Data(contentsOf: readURL)
        } catch {
            readError = error
        }
    }

    if let coordinatorError { throw coordinatorError }
    if let readError { throw readError }
    guard let result else { throw CocoaError(.fileReadUnknown) }
    return result
}
```

For writes, use `coordinate(writingItemAt:options:error:byAccessor:)`. Pair with `NSFilePresenter` conformance (`presentedItemURL`, `presentedItemDidChange()`) when you want to react to external edits — see CodeEdit's workspace watcher for a production example.

## Undo/redo integration with `NSUndoManager`

`NSDocument` owns an `NSUndoManager` and wires `Cmd+Z` / `Cmd+Shift+Z` into the Edit menu automatically. Register an undo block on every mutation so the user can walk backward.

```swift
extension TextDocument {
    @MainActor
    func setText(_ newText: String) {
        let oldText = text
        guard oldText != newText else { return }

        undoManager?.registerUndo(withTarget: self) { target in
            // Re-registers redo automatically when invoked during an undo.
            target.setText(oldText)
        }
        undoManager?.setActionName(NSLocalizedString("Typing", comment: ""))

        text = newText
        updateChangeCount(.changeDone)
    }
}
```

`setActionName(_:)` controls the Edit menu label ("Undo Typing", "Redo Typing"). For high-frequency actions like typing, coalesce registrations inside an `undoManager?.beginUndoGrouping()` / `endUndoGrouping()` pair or use `groupsByEvent = true` (the default). For the full `NSUndoManager` playbook — grouping strategies, value-type snapshotting, cross-document undo — read `user-interaction.md`.

## `NSDocumentController`

`NSDocumentController.shared` is the app-wide singleton that owns open documents, the recent documents menu, and new-document creation. You rarely subclass it. You occasionally call it.

```swift
NSDocumentController.shared.newDocument(nil)                     // File → New
NSDocumentController.shared.openDocument(nil)                    // File → Open…
NSDocumentController.shared.noteNewRecentDocumentURL(importedURL) // add to recents
// Enumerate every open document — useful for "save all" or global actions.
for document in NSDocumentController.shared.documents {
    document.save(nil)
}
```

Subclass `NSDocumentController` (and set it as the shared instance in `applicationWillFinishLaunching`) only when you need custom new-document behavior — e.g., opening a template picker instead of a blank document. Register the subclass by instantiating it before AppKit does: `_ = MyDocumentController()`.

## Multi-window per document

A single `NSDocument` can drive multiple windows — an editor window plus a live preview window, or split inspector panels. Add one `NSWindowController` per window in `makeWindowControllers()`; AppKit routes menu commands, `isDocumentEdited`, and close-on-save-all to every controller automatically.

```swift
final class MarkdownDocument: NSDocument {
    var source: String = ""

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        let editor = EditorWindowController()
        let preview = PreviewWindowController()

        addWindowController(editor)
        addWindowController(preview)

        // Both controllers share the same document; route the model through
        // whatever observation mechanism you use (Observable, Combine, NotificationCenter).
        editor.document = self
        preview.document = self
    }
}
```

Closing any window does not close the document — AppKit only closes the document when the last window controller goes away, or when the user explicitly closes the document. Override `shouldCloseWindowController(_:delegate:shouldClose:contextInfo:)` to veto or customize per-window close behavior.

## Security-scoped bookmarks

Sandboxed apps only have implicit permission to files the user grants via `NSOpenPanel`, drag-and-drop, or an incoming document. That permission is scoped to the current launch. To persist access across launches, capture a security-scoped bookmark and store it in `UserDefaults` (or a document sidecar). Sandbox entitlement setup is covered in `distribution.md`.

```swift
import Foundation

enum BookmarkStore {
    static let key = "RecentFolderBookmark"

    static func save(_ url: URL) throws {
        let data = try url.bookmarkData(options: .withSecurityScope,
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func restore() throws -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        let url = try URL(resolvingBookmarkData: data,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
        if isStale { try save(url) }  // Bookmark is still usable for this access.
        return url
    }

    static func withAccess<T>(to url: URL, _ body: (URL) throws -> T) throws -> T {
        guard url.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try body(url)
    }
}
```

Always pair `startAccessingSecurityScopedResource()` with `stopAccessingSecurityScopedResource()` in a `defer`. Leaking the access count silently breaks iCloud Drive sync on subsequent saves.

## Common pitfalls

- **Forgetting `autosavesInPlace = true`.** Users see "save changes?" dialogs everywhere and your app feels like it is from 2005. Opt in unless you have a concrete reason not to.
- **Synchronous reads/writes of large files on the main thread.** `data(ofType:)` runs on the main actor; for anything above a few megabytes, snapshot the model, hop to a background task to encode, and return the bytes.
- **Not registering undo actions.** `Cmd+Z` is load-bearing on macOS. Every user-visible mutation should register through `undoManager?.registerUndo(...)`.
- **Forgetting `stopAccessingSecurityScopedResource()`.** The access count leaks; later saves silently fail the coordinator. Use `defer`.
- **Mutating `NSDocument` state from background tasks without `@MainActor` annotation.** `NSDocument` is main-actor isolated; hop back explicitly when resolving from `async` work. Swift 6's strict concurrency will catch most of these at compile time — enable it.
- **Overriding `save(_:)` to implement serialization.** Override `data(ofType:)` or `write(to:ofType:)` instead; they're called by both save and autosave.
- **Using `LSHandlerRank = Owner` for a common file type.** You will steal `.txt` or `.md` from the user's existing app on first launch. Use `Alternate` unless you own the UTI.

## References

- **CotEditor — `Sources/Document/Document.swift`** — the cleanest production `NSDocument` to read: file encoding detection, incremental autosave, version integration.
- **CodeEdit — `WorkspaceDocument.swift`** — folder-as-document pattern where one `NSDocument` represents a project directory with multiple editor tabs.
- `references/user-interaction.md` — full `NSUndoManager` patterns, grouping, value-type snapshotting.
- `references/persistence.md` — non-document data (Core Data, SwiftData, `UserDefaults`, Keychain).
- `references/distribution.md` — sandbox entitlements for file access and security-scoped bookmarks.
- `references/windows-and-geometry.md` — `NSWindowController`, frame autosaving, multi-screen behavior.
- Apple — *Document-Based App Programming Guide for Mac*. Canonical but partially predates autosave-in-place; cross-check against the current SDK.
