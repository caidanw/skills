# Persistence: SwiftData, Core Data, SQLite, UserDefaults, Keychain

This reference covers persistence on macOS 14+: SwiftData for typed models, Core Data when you need CloudKit or iOS parity, GRDB when you want raw SQL and FTS5, `UserDefaults` for settings, Keychain for secrets, and the filesystem for blobs. The goal is matching the tool to the job and avoiding the common traps — secrets in `UserDefaults`, missed migrations, `synchronize()` calls that do nothing.

## Table of contents

- [Decision table](#decision-table)
- [SwiftData essentials](#swiftdata-essentials)
- [Core Data for CloudKit or iOS parity](#core-data-for-cloudkit-or-ios-parity)
- [GRDB for when you want SQL](#grdb-for-when-you-want-sql)
- [UserDefaults](#userdefaults)
- [UserDefaults pitfalls](#userdefaults-pitfalls)
- [Keychain for secrets](#keychain-for-secrets)
- [File-based storage locations](#file-based-storage-locations)
- [App Groups for sharing data](#app-groups-for-sharing-data)
- [Migrations](#migrations)
- [Async patterns](#async-patterns)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## Decision table

| Need                                                             | Use                                                         |
| ---                                                              | ---                                                         |
| Typed models, relationships, SwiftUI-first, macOS 14+            | SwiftData                                                   |
| Typed models, CloudKit sync, mature tooling, iOS compatibility   | Core Data                                                   |
| Raw SQL, fine control, FTS5, cross-platform SQLite               | GRDB                                                        |
| Key-value settings and preferences                               | `UserDefaults`                                              |
| Secrets, tokens, passwords                                       | Keychain                                                    |
| Document contents                                                | `NSDocument` / `FileDocument` (see `document-apps.md`)      |
| Large binary assets                                              | Filesystem in Application Support                           |

SwiftData is the path of least resistance for a new macOS 14+ app. Core Data is the default when you want CloudKit sync today or share a store with an iOS app. GRDB is right when you already think in SQL or need FTS5. Mixing is normal: SwiftData for the main object graph, `UserDefaults` for window state, Keychain for an API token, all in the same app.

## SwiftData essentials

SwiftData is Apple's declarative layer on top of Core Data. Models are plain Swift classes marked `@Model`. A `ModelContainer` owns the store; a `ModelContext` is the unit of read/write, like a Core Data `NSManagedObjectContext`. SwiftUI integrates via `.modelContainer(for:)` and the `@Query` macro.

```swift
import SwiftData
import SwiftUI

@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date

    init(title: String, body: String) {
        self.title = title
        self.body = body
        self.createdAt = .now
    }
}

@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup { NotesListView() }
            // Installs a shared ModelContainer into the SwiftUI environment;
            // every @Query and @Environment(\.modelContext) reads from it.
            .modelContainer(for: Note.self)
    }
}

struct NotesListView: View {
    // @Query re-runs whenever the store changes, so the view re-renders
    // as ordinary state-driven SwiftUI.
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var context

    var body: some View {
        List(notes) { Text($0.title) }
            .toolbar {
                Button("New") { context.insert(Note(title: "Untitled", body: "")) }
            }
    }
}
```

Key APIs: `context.insert(_:)`, `context.delete(_:)`, `try context.save()` (autosave is on by default; call `save()` explicitly before a critical boundary like termination). Use `@Query` for reactive reads in SwiftUI and `FetchDescriptor<Model>` for imperative reads.

**Caveat:** SwiftData on macOS 14 had rough edges — CloudKit sync gaps, migration bugs, relationship fetch issues. Check current release notes before committing a large production app. For anything non-trivial on macOS 14.x, Core Data is still the safer choice; SwiftData stabilized meaningfully in macOS 15+.

## Core Data for CloudKit or iOS parity

Reach for Core Data when you need **CloudKit sync** (SwiftData's CloudKit story is less mature), when sharing a store schema with an existing iOS app, or when you want the mature tooling (model editor, mapping models, Instruments integration). Minimal `NSPersistentCloudKitContainer` wiring inside an `NSApplicationDelegate`:

```swift
import AppKit
import CoreData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")
        // History tracking + remote change notifications are required for
        // CloudKit sync and multi-process scenarios (main app + widget).
        guard let desc = container.persistentStoreDescriptions.first else {
            fatalError("No store description in Core Data model")
        }
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data store failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    func applicationWillTerminate(_ notification: Notification) {
        let ctx = persistentContainer.viewContext
        if ctx.hasChanges { try? ctx.save() }
    }
}
```

A plain `NSPersistentContainer` is the same shape without the CloudKit subclass. Use `viewContext` for UI reads on the main actor and `performBackgroundTask { context in ... }` for writes that shouldn't block the main thread.

## GRDB for when you want SQL

[GRDB](https://github.com/groue/GRDB.swift) is a third-party SQLite toolkit (MIT licensed). Reach for it when you already know SQL and don't want an ORM in the way, need **FTS5** full-text search, want explicit migrations, or want the same store to work unchanged in a CLI tool or Linux build. Add via Swift Package Manager (`groue/GRDB.swift`); pin to a tagged release and check the current version before adopting.

```swift
import GRDB

struct Note: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var title: String
    var body: String
    var createdAt: Date
}

final class AppDatabase {
    let pool: DatabasePool

    init(path: String) throws {
        pool = try DatabasePool(path: path)
        // DatabaseMigrator runs each registered migration exactly once.
        // Never renumber or edit a shipped migration; add a new one.
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_notes") { db in
            try db.create(table: "note") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("body", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }
        try migrator.migrate(pool)
    }

    func insert(_ note: Note) async throws {
        try await pool.write { db in var copy = note; try copy.insert(db) }
    }
}

// Reactive read for SwiftUI. GRDBQuery's @FetchAll wraps this wiring.
let observation = ValueObservation.tracking { db in
    try Note.order(Column("createdAt").desc).fetchAll(db)
}
```

## UserDefaults

`UserDefaults` is a key-value store backed by a plist in the app container (or `~/Library/Preferences/<bundle-id>.plist` unsandboxed). It's the right home for small preferences — theme, window state, last-opened file, feature flags — and nothing larger.

```swift
// Raw access — cheap but values are Any?, so typing is on you.
UserDefaults.standard.set("dark", forKey: "theme")
let theme = UserDefaults.standard.string(forKey: "theme") ?? "system"

// Typed wrapper — each key gets one read/write site and a default.
@propertyWrapper
struct Defaults<Value> {
    let key: String
    let defaultValue: Value
    var wrappedValue: Value {
        get { (UserDefaults.standard.object(forKey: key) as? Value) ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// SwiftUI equivalent — @AppStorage reads UserDefaults.standard and triggers
// a view update on change. Prefer it inside views.
struct SettingsView: View {
    @AppStorage("theme") private var theme = "system"
    @AppStorage("showLineNumbers") private var showLineNumbers = true
    var body: some View { /* Form bindings omitted */ EmptyView() }
}
```

## UserDefaults pitfalls

- **Values are `Any?`** — type safety is your responsibility; use the `Defaults` wrapper above or `@AppStorage` with an explicit type.
- **`synchronize()` is a no-op** — vestigial on modern macOS; delete the calls.
- **Writes are batched**, not synchronous to disk. For anything that must survive an immediate crash, write to a file with `Data.write(to:options: .atomic)`.
- **Large blobs don't belong here** — anything over ~1 MB goes in the filesystem under Application Support.
- **Shared team settings belong in a cooperative file.** Defaults are per-user and per-machine; use a JSON/TOML file synced externally for org config.
- **Use a suite for App Group sharing** — `UserDefaults(suiteName: "group.com.example.MyApp")`, not `.standard`. See [App Groups for sharing data](#app-groups-for-sharing-data).

## Keychain for secrets

**Keychain is the only correct place to store API tokens, OAuth refresh tokens, user passwords, and encryption keys.** Never put secrets in `UserDefaults`, plist files inside the bundle, or flat files on disk — any of those is a security bug.

The raw API is `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete` from the Security framework. Minimal wrapper for a token:

```swift
import Security
import Foundation

enum KeychainError: Error { case unexpectedStatus(OSStatus) }

enum TokenStore {
    private static let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.example.MyApp",
        kSecAttrAccount as String: "api-token",
    ]

    static func set(_ token: String) throws {
        // Delete any existing entry so SecItemAdd doesn't collide.
        SecItemDelete(baseQuery as CFDictionary)
        var add = baseQuery
        add[kSecValueData as String] = Data(token.utf8)
        // Require device unlock; the item never syncs off this device.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func get() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        return (item as? Data).map { String(decoding: $0, as: UTF8.self) }
    }
}
```

If you'd rather skip the boilerplate, the community [`KeychainAccess`](https://github.com/kishikawakatsumi/KeychainAccess) library (MIT) wraps all of the above in a typed API:

```swift
import KeychainAccess

let keychain = Keychain(service: "com.example.MyApp")
try keychain.set("token-value", key: "api-token")
let token = try keychain.get("api-token")
```

Either approach is fine. Know the raw API so you can debug `OSStatus` values and understand `kSecAttrAccessible`, access groups, and iCloud sync flags.

## File-based storage locations

| Directory           | Path helper                                                                                    | Use for                                                         |
| ---                 | ---                                                                                            | ---                                                             |
| Application Support | `FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask)`              | App data, local caches you want to persist across launches      |
| Caches              | `.cachesDirectory`                                                                             | Regenerable data; macOS can delete under memory pressure        |
| Documents           | `.documentDirectory`                                                                           | User documents (uncommon on macOS; mostly an iOS convention)    |
| Temporary           | `FileManager.default.temporaryDirectory`                                                       | Scratch files; cleaned up by the system                         |

Inside a sandboxed app, each of these resolves to a subdirectory of the app's container (`~/Library/Containers/<bundle-id>/Data/...`), not the user's real `~/Library`. Always scope Application Support to your bundle identifier:

```swift
let fm = FileManager.default
// Application Support is shared across apps; scoping to bundle id keeps
// the layout discoverable and avoids collisions.
let root = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                      appropriateFor: nil, create: true)
let appFolder = root.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MyApp")
try fm.createDirectory(at: appFolder, withIntermediateDirectories: true)
```

## App Groups for sharing data

When the main app, a widget, a `SMAppService` helper, or a Finder extension need to share data, use App Groups. Add `com.apple.security.application-groups` with a `group.<bundle-id>` identifier to every target that needs access. See `distribution.md` for entitlement wiring.

```swift
let groupID = "group.com.example.MyApp"

// Shared container on disk — for files, databases, blobs.
guard let shared = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
    fatalError("App Group container missing — check entitlements")
}

// Shared UserDefaults — for small settings visible to every target.
let sharedDefaults = UserDefaults(suiteName: groupID)
sharedDefaults?.set(true, forKey: "widget.enabled")
```

SwiftData, Core Data, and GRDB stores all work inside the group container — put the database at `shared.appendingPathComponent("db.sqlite")` and every target loads the same store.

## Migrations

Ship v1 with a migration strategy already in place, not bolted on when v2's schema change hits.

- **SwiftData** — versioned schemas via `VersionedSchema` and a `SchemaMigrationPlan` chaining `MigrationStage.lightweight(...)` and `.custom(...)` between versions. Lightweight handles added properties and `@Attribute(originalName:)` renames; structural changes need a custom stage.
- **Core Data** — lightweight migration covers most additions and renames automatically; heavier changes use an `.xcmappingmodel` generated in Xcode. Toggle via `NSPersistentStoreDescription.shouldInferMappingModelAutomatically` and `shouldMigrateStoreAutomatically`.
- **GRDB** — `DatabaseMigrator` with explicit SQL per step. Each migration runs exactly once and is recorded by name; **never renumber or edit a shipped migration** — add a new one.

Test with a copy of the previous version's store file committed into the test bundle. "Launches without crashing on an empty DB" is not a migration test.

## Async patterns

Don't block the main thread on IO. Each persistence tool has its own off-main entry point:

- **SwiftData** — the default `ModelContext` is main-actor-bound. Declare a background actor with `@ModelActor` (e.g. `@ModelActor actor Importer { ... }`) and run heavy writes inside it.
- **Core Data** — `persistentContainer.performBackgroundTask { ctx in ... }` gives you a private-queue context; save there, then `viewContext.automaticallyMergesChangesFromParent` pulls the result onto the main context.
- **GRDB** — `try await pool.write { db in ... }` is async-aware and serializes writers; `pool.read` is non-blocking for readers.

For reads feeding SwiftUI, prefer the reactive APIs — `@Query` (SwiftData), `@FetchRequest` (Core Data), `ValueObservation` (GRDB) — over one-shot async reads. Reactive reads keep UI and store in lockstep.

## Common pitfalls

- **API tokens in `UserDefaults`** — security bug. Use Keychain. Every time.
- **Calling `UserDefaults.standard.synchronize()`** — no-op. Delete it.
- **Not testing migrations before shipping** — keep an old store file in test fixtures and run it through the migrator on every release.
- **Using SwiftData for a large production app without checking known issues** — Apple Developer Forums and release notes first; bugs acceptable on a side project can be shipping blockers.
- **Writing to the app bundle** — signed apps are read-only. Writable data belongs in Application Support, Caches, or the temporary directory.
- **Using `Documents` for hidden app data on macOS** — `Documents` is user-visible; internal data belongs in Application Support.
- **Assuming a sandboxed app can read arbitrary paths** — files outside the container need a security-scoped bookmark (from `NSOpenPanel`) or an entitlement. See `user-interaction.md`.
- **Treating `Caches` as durable** — the OS can delete it under memory pressure.

## References

- **Rectangle** — `UserDefaults` + `@AppStorage` for window-management preferences.
- **Xcodes.app** — Combine-driven store layered over a persistent model; case study for reactive reads.
- **CotEditor** — Core Data for document metadata, filesystem for document contents; shows the structured/unstructured split in one app.
- `document-apps.md` — `NSDocument` / `FileDocument` for document-centric storage.
- `distribution.md` — App Group entitlements, sandbox, and signing for shared containers.
- Apple, ["Loading and Saving Data with SwiftData"](https://developer.apple.com/documentation/swiftdata) and the *Meet SwiftData* WWDC session.
- Apple, ["Mirroring a Core Data Store with CloudKit"](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit).
- [GRDB.swift documentation](https://swiftpackageindex.com/groue/GRDB.swift/documentation) — migrations, `ValueObservation`, FTS5.
- [`KeychainAccess`](https://github.com/kishikawakatsumi/KeychainAccess) — community Keychain wrapper.
