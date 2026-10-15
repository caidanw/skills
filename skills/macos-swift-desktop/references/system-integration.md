# System Integration: XPC, SMAppService, App Intents, Handoff, FileProvider

This reference covers how a macOS desktop app plugs into the rest of the system: separating privileged or risky work into XPC helpers, registering launchd login items and daemons via `SMAppService`, exposing actions to Shortcuts and Siri with App Intents, participating in Handoff via `NSUserActivity`, integrating with Finder via FileProvider, and scheduling local notifications. Each section is a minimal working shape — not a full treatment — with pointers to the canonical reference apps.

## Table of contents

- [XPC: privilege and process separation](#xpc-privilege-and-process-separation)
- [Two flavors of XPC helpers](#two-flavors-of-xpc-helpers)
- [Defining an XPC protocol](#defining-an-xpc-protocol)
- [Client side (main app)](#client-side-main-app)
- [Service side (helper target)](#service-side-helper-target)
- [SMAppService](#smappservice)
- [App Intents](#app-intents)
- [AppShortcut](#appshortcut)
- [NSUserActivity and Handoff](#nsuseractivity-and-handoff)
- [FileProvider](#fileprovider)
- [Local notifications](#local-notifications)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## XPC: privilege and process separation

A sandboxed macOS app cannot do most of the things a system-wide tool needs to do: touch files outside its container, bind privileged ports, inspect or control other processes, or run anything as root. The standard pattern is to split the work: keep the sandboxed GUI in the main app, and hand the risky or privileged operations to a separate helper process connected by **XPC** — macOS's lightweight IPC built on top of Mach messaging.

Why bother with a helper process at all:

- **Sandboxing** — the helper can hold entitlements the main app must not (network-server, temporary-exception file access, root).
- **Fault isolation** — a crash in the helper doesn't take down the UI; launchd restarts it.
- **Privilege minimization** — the risky code runs in the smallest possible binary with the smallest possible entitlement set.
- **Third-party code isolation** — bundling an Electron runtime, a language runtime, or any large untrusted dependency in a separate process keeps it out of your main app's crash reports.

**Xcodes.app** is the canonical production example of this pattern — see its privileged helper target and its use of `SMAppService`. Cross-reference `reference-repos.md`.

## Two flavors of XPC helpers

| Flavor | Install location | Privilege | Registration | Use case |
| --- | --- | --- | --- | --- |
| XPC service | `Contents/XPCServices/` inside the app bundle | User, sandboxed | Auto-discovered by bundle ID | Isolating third-party code, running a local web server, heavy work off the main process |
| Privileged helper tool | `/Library/PrivilegedHelperTools/` | Root (via `launchd`) | `SMAppService.daemon` (modern) or `SMJobBless` (legacy) | Installers, VPN configuration, window managers that need accessibility at boot, system-wide file ops |

Non-privileged XPC services are cheap — ship them when you want process separation. Privileged helper tools are expensive: they require user authorization via the Authorization framework, an admin password prompt, and careful entitlement review. Only use one when you genuinely need to modify system state.

## Defining an XPC protocol

The wire contract between main app and helper is an `@objc` protocol. XPC proxies through the Objective-C runtime, so every method argument and return type must be a type NSXPC can encode: `NSData`, `NSString`, `NSNumber`, collections of those, and classes conforming to `NSSecureCoding`.

```swift
import Foundation

@objc protocol BackgroundWorker {
    func performWork(with payload: Data) async throws -> Data
}
```

Keep the protocol narrow: each method is an RPC boundary that becomes part of your compatibility surface once the helper ships.

## Client side (main app)

The main app opens an `NSXPCConnection` to a named service, installs the interface, resumes the connection, and obtains a remote object proxy. Bridging the proxy to Swift concurrency is enough for most call sites:

```swift
enum XPCError: Error { case connectionFailed }

@MainActor
final class WorkerClient {
    private let connection: NSXPCConnection

    init() {
        connection = NSXPCConnection(serviceName: "com.example.MyApp.Worker")
        connection.remoteObjectInterface = NSXPCInterface(with: BackgroundWorker.self)
        connection.resume()
    }

    func performWork(with data: Data) async throws -> Data {
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            // Transport-level failure; the continuation below still needs to resume.
        } as? BackgroundWorker
        guard let proxy else { throw XPCError.connectionFailed }
        return try await proxy.performWork(with: data)
    }

    deinit { connection.invalidate() }
}
```

This is a deliberately simplified shape. Production apps should use Matt Massicotte's **`AsyncXPCConnection`** package (or **`SecureXPC`**) for correct error propagation, interruption handling, and continuation safety. The `remoteObjectProxyWithErrorHandler` + `async` combination has subtle races when the connection is interrupted mid-call. See `reference-repos.md` for Xcodes.app's production wiring.

## Service side (helper target)

The helper is a separate target — **macOS → Application → XPC Service** in Xcode — that builds a tiny bundle with its own `Info.plist` and binary. The target's output is copied into `Contents/XPCServices/` via a **Build Phases → Copy Files → XPC Services** phase on the main app target. launchd discovers and launches it on first connection; nothing else is required.

```swift
// main.swift in the XPC Service target.
import Foundation

final class WorkerService: NSObject, BackgroundWorker, NSXPCListenerDelegate {
    func performWork(with payload: Data) async throws -> Data {
        // Do the work here. This runs in the helper process.
        return payload
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: BackgroundWorker.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }
}

let delegate = WorkerService()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()  // Blocks; returns only on teardown.
```

Log through `os.Logger` and read the service's output in Console.app filtered by subsystem — `print` output from a helper does not reach the main app's stdout.

## SMAppService

`SMAppService` (macOS 13+) is the modern replacement for the deprecated `SMLoginItemSetEnabled` and `SMJobBless` APIs. It covers four install shapes from a single framework, all approved by the user via **System Settings → General → Login Items**.

```swift
import ServiceManagement

// 1. Main app starts at login.
let mainApp = SMAppService.mainApp

// 2. A helper app (no UI, separate bundle) as a login item.
let loginItem = SMAppService.loginItem(identifier: "com.example.MyApp.LoginHelper")

// 3. A launchd agent running in the user's session.
let agent = SMAppService.agent(plistName: "com.example.MyApp.agent.plist")

// 4. A launchd daemon running as root.
let daemon = SMAppService.daemon(plistName: "com.example.MyApp.daemon.plist")

try mainApp.register()
// mainApp.status -> .enabled, .notRegistered, .notFound, .requiresApproval
try mainApp.unregister()
```

The four shapes in plain English:

- **Main app at login** — simplest case. The user's session launches the app. Appropriate for status-bar apps that should always be running.
- **Login item** — a separate helper bundle with no UI that starts with the user. Use this when the main app only needs a daemon-like companion at login (e.g. a background sync worker) and should not itself auto-launch.
- **Agent** — a launchd-managed process in the user context; can run on demand (`RunAtLoad`, `StartCalendarInterval`, `KeepAlive`). Use for scheduled or on-demand background work that does not need root.
- **Daemon** — launchd-managed, runs as root in the system context. Requires admin approval on first registration and shows up in Login Items with a shield. Use only when root is genuinely required.

Agents and daemons require a bundled launchd property list at `Contents/Library/LaunchAgents/<name>.plist` or `Contents/Library/LaunchDaemons/<name>.plist` inside the main app bundle; `SMAppService` reads the plist from there at registration time. Always check `.status` before calling `.register()` — if the user declined a previous registration, the status will be `.requiresApproval` and the correct action is to surface a UI pointing the user to System Settings, not to retry.

## App Intents

`AppIntents` (macOS 14+) is how your app exposes actions to **Shortcuts**, **Spotlight**, and **Siri**. It replaces the older SiriKit and Intents framework for almost all new apps. An intent is a struct conforming to `AppIntent` with parameters and a `perform()` method.

```swift
import AppIntents

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription("Create a new note with the given text.")

    @Parameter(title: "Content")
    var content: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let note = try NoteStore.shared.create(content: content)
        return .result(dialog: "Created note \(note.title)")
    }
}
```

Intents compiled into the app target appear automatically in Shortcuts under your app's name — no manual registration. Parameter types must be `Codable` or one of the intent-aware types (`String`, `Int`, `Date`, `URL`, `IntentFile`, `AppEntity` subclasses, etc.). Mark `perform()` `@MainActor` when it touches app state on the main actor; if the work is genuinely background, leave it `nonisolated` and dispatch explicitly.

## AppShortcut

An `AppShortcut` is a hardcoded phrase the user can speak to Siri or tap in Shortcuts without building a custom shortcut first. Declare them in an `AppShortcutsProvider`:

```swift
struct MyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: ["Create a note with \(.applicationName)"],
            shortTitle: "Create Note",
            systemImageName: "note.text.badge.plus"
        )
    }
}
```

`\(.applicationName)` interpolates the localized app name — required in at least one phrase per shortcut.

## NSUserActivity and Handoff

`NSUserActivity` is the mechanism for Handoff (continuing work between devices), Spotlight indexing of in-app content, and state restoration. To make an activity handoffable, publish it from the view that owns the work:

```swift
let activity = NSUserActivity(activityType: "com.example.MyApp.editingNote")
activity.title = note.title
activity.userInfo = ["noteID": note.id.uuidString]
activity.requiredUserInfoKeys = ["noteID"]
activity.isEligibleForHandoff = true
activity.becomeCurrent()
```

The `activityType` must be listed under `NSUserActivityTypes` in the receiving app's `Info.plist`. To receive on the Mac side, implement `application(_:continue:restorationHandler:)` on `NSApplicationDelegate`, or — in a SwiftUI root — attach `.onContinueUserActivity(_:perform:)`:

```swift
.onContinueUserActivity("com.example.MyApp.editingNote") { activity in
    guard let idString = activity.userInfo?["noteID"] as? String,
          let id = UUID(uuidString: idString) else { return }
    openNote(id: id)
}
```

Set `requiredUserInfoKeys` — Handoff silently drops activities that don't declare them.

## FileProvider

`NSFileProviderExtension` is the modern extension point for cloud-sync providers: Dropbox, Google Drive, iCloud Drive, your own sync service. It replaces **Finder Sync extensions** for new projects and is the only supported API for deep Finder integration on recent macOS. A FileProvider extension vends a virtual filesystem to Finder, handles background sync, and participates in the macOS file coordination model.

Full coverage is out of scope for this doc — FileProvider is a complete subsystem with its own domain model, working set semantics, enumeration protocols, and materialization rules. Start with Apple's [FileProvider framework documentation](https://developer.apple.com/documentation/fileprovider) and Claudio Cambra's writeups on building a production FileProvider extension. If your only goal is a context menu item in Finder, prefer an `AppIntent` or an **Open With** handler before committing to the FileProvider surface area.

## Local notifications

Local notifications go through `UNUserNotificationCenter`. Authorization is mandatory — requesting it is free, but posting without it silently fails.

```swift
import UserNotifications

let center = UNUserNotificationCenter.current()
let granted = try await center.requestAuthorization(options: [.alert, .sound])
guard granted else { return }

let content = UNMutableNotificationContent()
content.title = "Sync complete"
content.body = "Finished indexing \(count) files"

let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: trigger
)
try await center.add(request)
```

Check `await center.notificationSettings().authorizationStatus` before posting — users can revoke authorization in System Settings at any time, and a revoked app gets no error when it calls `add(_:)`; the notification just never appears.

## Common pitfalls

- **Using `NSUserNotification`** — the old `NSUserNotificationCenter` API is deprecated and silently no-ops on modern macOS. Always use `UserNotifications`.
- **`SMAppService.register()` throwing because the user hasn't approved the item yet.** Check `.status` first and handle `.requiresApproval` by pointing the user at **System Settings → General → Login Items** — never retry blindly.
- **XPC service crashes disappear.** launchd auto-restarts the service, so a repeatedly-crashing helper can look healthy from the main app's side. Log via `os.Logger` with a clear subsystem and filter in Console.app to find the real error.
- **Forgetting `connection.resume()`** — an `NSXPCConnection` that has never been resumed accepts no messages and produces no error; calls just hang. Resume immediately after setting `remoteObjectInterface`.
- **AppIntent parameters that aren't intent-compatible.** `@Parameter` only accepts `Codable` types Apple has blessed for intents; custom structs must be `AppEntity` or wrapped in one.
- **Handoff activities missing `requiredUserInfoKeys`.** The system drops activities without the field, and there is no console warning.
- **Strong references across the XPC boundary.** The remote object proxy is a proxy — capturing it strongly in a long-lived closure can outlive the connection; always fetch a fresh proxy per call.
- **Bundling the helper without the Copy Files phase.** An XPC service target that builds successfully but isn't embedded at `Contents/XPCServices/` will never be found; check the archive's bundle contents during CI.
- **Root daemons with wide entitlements.** A daemon you install via `SMAppService.daemon` runs as root — keep its binary tiny, review its entitlements line by line, and never share code with the main app that assumes sandboxed constraints.

## References

- `reference-repos.md` — **Xcodes.app** is the canonical production example of an `SMAppService` privileged helper plus XPC wiring; its `XPCServiceTarget/` directory is worth reading end to end.
- Matt Massicotte's **`AsyncXPCConnection`** and **`SecureXPC`** packages — production-quality Swift concurrency bridges for `NSXPCConnection`.
- `distribution.md` — entitlements, code signing, and notarization requirements for XPC services and helper tools (helpers inherit the main app's team ID but need their own entitlement plist).
- Apple documentation — `NSXPCConnection`, `SMAppService`, `AppIntent`, `NSUserActivity`, `UNUserNotificationCenter`, `NSFileProviderExtension`. Always verify signatures against the current SDK.
- WWDC sessions — search for "SMAppService", "App Intents", "XPC", "FileProvider"; specific session numbers change year to year.
