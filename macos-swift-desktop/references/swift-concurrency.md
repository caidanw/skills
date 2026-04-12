# Swift Concurrency: Problematic Patterns

Patterns that compile but cause subtle bugs, deadlocks, or undermine Swift's concurrency safety model. Based on [Matt Massicotte's "Problematic Patterns"](https://www.massicotte.org/problematic-patterns/) with macOS desktop-specific context added.

These apply everywhere — AppKit, SwiftUI, XPC, testing — so treat this as a cross-cutting reference.

## Table of contents

- [Split isolation](#split-isolation)
- [Task.detached for actor escaping](#taskdetached-for-actor-escaping)
- [Explicit task priorities without justification](#explicit-task-priorities-without-justification)
- [MainActor.run overuse](#mainactorrun-overuse)
- [Stateless actors](#stateless-actors)
- [Redundant Sendable conformances](#redundant-sendable-conformances)
- [MainActor + Sendable closures](#mainactor--sendable-closures)
- [RunLoop-dependent APIs off MainActor](#runloop-dependent-apis-off-mainactor)
- [Actors conforming to synchronous protocols](#actors-conforming-to-synchronous-protocols)
- [Blocking for async work](#blocking-for-async-work)
- [Unstructured concurrency when structured works](#unstructured-concurrency-when-structured-works)
- [preconcurrency import with async extensions](#preconcurrency-import-with-async-extensions)
- [Objective-C async translations](#objective-c-async-translations)
- [Too much code in closures](#too-much-code-in-closures)
- [Non-Sendable types without isolated parameters](#non-sendable-types-without-isolated-parameters)

## Split isolation

**Don't** mix isolated and non-isolated properties on the same type:

```swift
// Bad — `value` is MainActor-isolated but the type isn't Sendable.
// Instances created off MainActor can never safely access `value`.
class SomeClass {
    var name: String
    @MainActor var value: Int
}
```

**Do** isolate the entire type:

```swift
@MainActor
final class SomeClass {
    var name: String
    var value: Int
}
```

If only some properties need MainActor, the type likely has a design problem — split it into two types with clear isolation boundaries.

## Task.detached for actor escaping

**Don't** use `Task.detached` just to escape actor isolation:

```swift
@MainActor
func doSomeStuff() {
    Task.detached {
        expensiveWork()  // escapes MainActor, but also discards priority + task-locals
    }
}
```

`Task.detached` doesn't just remove isolation — it discards task priority and task-local values. Usually not what you want.

**Do** use `nonisolated` functions:

```swift
@MainActor
func doSomeStuff() {
    Task {
        await expensiveWork()
    }
}

nonisolated func expensiveWork() async {
    // Runs off MainActor, inherits priority and task-locals
}
```

## Explicit task priorities without justification

**Don't** set priority without explaining why:

```swift
Task(priority: .background) {
    await someWork()
}
```

Explicit priorities risk priority inversions. The runtime's default priority inheritance is almost always correct. If you override it, leave a comment explaining the constraint.

## MainActor.run overuse

**Don't** sprinkle `MainActor.run` to move work onto the main thread:

```swift
func updateUI() async {
    await MainActor.run {
        label.text = "Done"
    }
}
```

This opts out of the compiler's static isolation checking. You're doing the compiler's job by hand and will miss cases.

**Do** declare the function `@MainActor`:

```swift
@MainActor
func updateUI() {
    label.text = "Done"
}
```

The compiler enforces callers use `await`, and you can't accidentally call non-isolated code without awareness.

**When `MainActor.run` is OK:** one-shot closures where a function genuinely crosses isolation boundaries (e.g., a `nonisolated` callback that needs to touch one UI element). Even then, prefer extracting a `@MainActor` helper.

## Stateless actors

**Don't** create actors with no mutable state:

```swift
actor ImageDownloader {
    func download(url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}
```

Actors exist to serialize access to mutable state. A stateless actor is just an expensive way to move work off the main thread — every call pays the async hop for no protection benefit.

**Do** use a `nonisolated` function or a plain struct:

```swift
enum ImageDownloader {
    static func download(url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}
```

## Redundant Sendable conformances

**Don't** explicitly conform global-actor-isolated types to `Sendable`:

```swift
@MainActor
class SomeClass: Sendable { }  // redundant
```

`@MainActor` types are automatically `Sendable` because the actor guarantees safe access. The explicit conformance signals misunderstanding and can mask real Sendable issues elsewhere.

## MainActor + Sendable closures

On **Swift 6+**, `@MainActor` closures are implicitly `Sendable`. Don't double-annotate:

```swift
// Swift 5 required both (compile fix, not ideal):
let callback: @MainActor @Sendable () -> Void

// Swift 6+ — just use @MainActor:
let callback: @MainActor () -> Void
```

If you're still on Swift 5 mode, the double annotation is a necessary evil. Mark it with a `// TODO: remove @Sendable when adopting Swift 6 language mode` so future cleanup is obvious.

## RunLoop-dependent APIs off MainActor

`Timer` (née `NSTimer`), `URLSession` delegate callbacks, `JavaScriptCore`, and many AppKit APIs implicitly require the main run loop. Moving them off `@MainActor` causes silent misbehavior — timers don't fire, delegates aren't called.

**Rule:** if an API existed before Swift concurrency and its documentation mentions "run loop" or "main thread," keep it `@MainActor`-isolated. Don't move it to a background actor for "performance."

Common offenders in macOS desktop apps:
- `Timer.scheduledTimer` — must be on main run loop
- `NotificationCenter.default.addObserver` with a nil queue — delivers on posting thread, not main
- `WKWebView` delegate methods — main thread only
- `NSEvent` handling — always main thread

## Actors conforming to synchronous protocols

**Don't** conform an actor to a protocol that has synchronous requirements:

```swift
protocol DataSource {
    var count: Int { get }
    func item(at index: Int) -> Item
}

actor Store: DataSource {
    var items: [Item] = []
    var count: Int { items.count }        // can't safely call from outside
    func item(at index: Int) -> Item { items[index] }  // same problem
}
```

Synchronous protocol methods can't be called from outside the actor without `await`, but the protocol signature doesn't allow `await`. This forces `nonisolated` which breaks isolation, or requires callers to use `assumeIsolated`.

**Do** reconsider whether an actor is correct here. A `@MainActor` class or a struct behind a lock might fit the protocol better.

## Blocking for async work

**Don't** use `DispatchSemaphore` or `DispatchGroup` to wait on async work:

```swift
let semaphore = DispatchSemaphore(value: 0)
Task {
    await doAsyncWork()
    semaphore.signal()
}
semaphore.wait()  // deadlock risk if on cooperative thread pool
```

Swift's cooperative thread pool has a fixed number of threads. Blocking one while waiting for async work that needs the same pool = deadlock. This is especially dangerous on macOS because AppKit main-thread work + cooperative pool work can create circular waits.

**Do** use structured concurrency:

```swift
let result = await doAsyncWork()
```

If you're at a sync/async boundary (e.g., `NSApplicationDelegate` method that can't be async), use `Task { ... }` and deliver results via callback or `@Published`.

## Unstructured concurrency when structured works

**Don't** create `Task` instances when `async let` or `TaskGroup` would do:

```swift
// Bad — fire-and-forget tasks lose automatic cancellation
func loadDashboard() async {
    Task { await loadProfile() }
    Task { await loadActivity() }
    Task { await loadSettings() }
}
```

These tasks aren't children of `loadDashboard`. If `loadDashboard` is cancelled, the three inner tasks keep running.

**Do** use structured concurrency:

```swift
func loadDashboard() async {
    async let profile = loadProfile()
    async let activity = loadActivity()
    async let settings = loadSettings()
    let (p, a, s) = await (profile, activity, settings)
}
```

Now cancellation propagates automatically.

## preconcurrency import with async extensions

**Be careful** when wrapping old completion-handler APIs with async alternatives while using `@preconcurrency import`:

```swift
@preconcurrency import SomeFramework

extension SomeClass {
    func doWork() async -> Result {
        await withCheckedContinuation { continuation in
            doWork { result in
                continuation.resume(returning: result)
            }
        }
    }
}
```

The `@preconcurrency` suppresses warnings that might reveal the completion handler runs on a different thread than expected. Your async wrapper may silently move work from the main thread to a background thread, changing semantics.

**Rule:** when wrapping completion-handler APIs, always verify which thread the completion fires on. Add `@MainActor` to the wrapper if the completion was previously main-thread.

## Objective-C async translations

The Swift compiler auto-generates `async` versions of Objective-C completion-handler methods. These translations can change threading behavior unless the original type is `@MainActor`-isolated or `Sendable`.

In macOS desktop apps, this commonly bites with `NSDocument`, `NSSavePanel`, `NSAlert`, and `WKWebView` delegate methods. If the auto-generated async version isn't behaving correctly, check whether the original Objective-C method had main-thread assumptions that the translation dropped.

Use `@preconcurrency` on the import if needed, but see the previous section for the risks.

## Too much code in closures

**Don't** write dense multi-statement closures in concurrent code:

```swift
Task {
    let data = try await fetch(url)
    let parsed = try decoder.decode(Model.self, from: data)
    await MainActor.run {
        self.model = parsed
        self.isLoading = false
        self.updateUI()
    }
}
```

Long closures make compiler diagnostics inscrutable ("type of expression is ambiguous without more context" pointing at a 30-line closure). They also hide isolation boundaries.

**Do** extract into named functions:

```swift
Task {
    let model = try await fetchAndParse(url)
    await applyModel(model)
}

nonisolated func fetchAndParse(_ url: URL) async throws -> Model {
    let data = try await fetch(url)
    return try decoder.decode(Model.self, from: data)
}

@MainActor func applyModel(_ model: Model) {
    self.model = model
    self.isLoading = false
    updateUI()
}
```

Smaller functions = better diagnostics, clearer isolation, easier testing.

## Non-Sendable types without isolated parameters

Non-`Sendable` types can safely participate in concurrency via isolated parameters:

```swift
// This type isn't Sendable, but we can still use it in async code
// by requiring callers to pass an isolation context.
class DocumentProcessor {
    var state: ProcessingState

    func process(isolation: isolated (any Actor)? = #isolation) async {
        // `isolation` proves we're running in the caller's isolation context,
        // so accessing `state` is safe without Sendable.
        state = .processing
        let result = await heavyWork()
        state = .done(result)
    }
}
```

If you're adding async methods to a non-`Sendable` type and getting warnings, isolated parameters are the modern fix. Don't slap `@unchecked Sendable` on the type — that hides real bugs.

## Desktop-specific concurrency notes

- **AppKit views are `@MainActor`** — all `NSView`, `NSViewController`, `NSWindow` work must stay on MainActor. Don't use `nonisolated` overrides on view methods unless you're explicitly doing background work and syncing back.
- **`NSDocument` save/read can be async** — `read(from:ofType:)` and `data(ofType:)` are called on the main thread by default. If you need background IO, use `canConcurrentlyReadDocuments(ofType:)` and handle your own isolation.
- **XPC proxies are nonisolated** — `NSXPCConnection.remoteObjectProxyWithErrorHandler` returns a nonisolated proxy. Calls to it are inherently async. Don't wrap the result in `MainActor.run` — just make the calling function `nonisolated` and hop to MainActor for the result.
- **`CVDisplayLink` callbacks are off-main-thread** — the callback in `advanced-rendering.md` dispatches to main explicitly. Don't call `@MainActor` functions directly from the callback.

## Source

[Matt Massicotte — "Problematic Patterns"](https://www.massicotte.org/problematic-patterns/)

See also Matt's other concurrency writing at [massicotte.org](https://www.massicotte.org/) and his [ConcurrencyRecipes](https://github.com/mattmassicotte/ConcurrencyRecipes) repo.
