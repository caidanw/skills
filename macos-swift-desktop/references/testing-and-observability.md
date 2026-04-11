# Testing and Observability

This reference covers how to test and observe a macOS Swift desktop app in production: XCTest and Swift Testing basics, async test patterns, mocking at the right seams, UI tests with `XCUIApplication`, `NSDocument`/`NSViewController` unit patterns, performance measurement, `Logger` with privacy markers, `OSSignposter` for Instruments, the Instruments templates you will actually use, Console.app log inspection, and crash reporting options including `MetricKit`.

## Table of contents

- [XCTest basics](#xctest-basics)
- [Swift Testing framework](#swift-testing-framework)
- [Async test patterns](#async-test-patterns)
- [Mocking boundaries](#mocking-boundaries)
- [UI tests with XCUIApplication](#ui-tests-with-xcuiapplication)
- [Test targets in Package.swift and Xcode](#test-targets-in-packageswift-and-xcode)
- [Testing NSDocument and NSViewController](#testing-nsdocument-and-nsviewcontroller)
- [Performance tests](#performance-tests)
- [OSLog and Logger](#oslog-and-logger)
- [Signposts for Instruments](#signposts-for-instruments)
- [Instruments profiling](#instruments-profiling)
- [Logging configuration for Console.app](#logging-configuration-for-consoleapp)
- [Crash reporting options](#crash-reporting-options)
- [Common pitfalls](#common-pitfalls)
- [References](#references)

## XCTest basics

The minimum useful test case: import the module under test with `@testable` so internal declarations are visible, and annotate methods that touch AppKit or SwiftUI types with `@MainActor` so the compiler enforces the main-thread contract.

```swift
import XCTest
@testable import MyApp

final class DocumentTests: XCTestCase {
    @MainActor
    func testDocumentReadsMarkdown() throws {
        // XCTUnwrap reports a descriptive failure instead of crashing when
        // the encoding returns nil — which can't happen here, but the habit
        // matters for tests that aren't trivially reviewable.
        let data = try XCTUnwrap("# Hello".data(using: .utf8))
        let sut = try Document(data: data, ofType: "public.plain-text")
        XCTAssertEqual(sut.title, "Hello")
    }
}
```

Name tests `testX` (XCTest discovers them by prefix). Use `throws` so setup errors fail the test cleanly rather than forcing `try!`. `@testable import` only works when the target under test was built with testing enabled (`-enable-testing`), which Xcode and SwiftPM do by default for debug configurations.

## Swift Testing framework

macOS 14+ can use the newer `swift-testing` package as an alternative to XCTest. It uses `@Test` functions, `#expect` for soft assertions, and `#require` for preconditions that short-circuit the test.

```swift
import Testing
@testable import MyApp

@Test @MainActor
func documentReadsMarkdown() throws {
    let sut = try Document(data: #require("# Hello".data(using: .utf8)), ofType: "public.plain-text")
    #expect(sut.title == "Hello")
}
```

Swift Testing gives you parameterized tests, tags, and better failure diagnostics. XCTest is still the default and is required for anything that uses `XCTMetric`-based performance tests or integrates with Xcode's UI-testing harness; mixing both in the same target is supported.

## Async test patterns

`async` test methods are supported directly. Do not wrap `async` code in `XCTestExpectation` — expectations are a legacy pattern for callback-based APIs.

```swift
@MainActor
func testLoadNotes() async throws {
    let store = NoteStore()
    let notes = try await store.loadAll()
    XCTAssertFalse(notes.isEmpty)
}
```

Only reach for `XCTestExpectation` and `wait(for:timeout:)` when the code under test is a delegate callback, an `NSNotification`, or a completion handler that has no `async` wrapper. For anything you can `await`, await it.

## Mocking boundaries

Do not mock Apple frameworks directly — wrap them. Define a protocol at each boundary your app doesn't own (network, filesystem, clock, keychain, user defaults, XPC) and inject a fake in tests. The production type and the fake both conform to the protocol.

```swift
protocol Clock: Sendable {
    func now() -> Date
    func sleep(until deadline: Date) async throws
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
    func sleep(until deadline: Date) async throws {
        try await Task.sleep(until: .init(.now + .seconds(deadline.timeIntervalSinceNow)), clock: .continuous)
    }
}

final class FakeClock: Clock, @unchecked Sendable {
    private var current: Date
    init(start: Date = Date(timeIntervalSince1970: 0)) { self.current = start }
    func now() -> Date { current }
    func advance(by interval: TimeInterval) { current.addTimeInterval(interval) }
    func sleep(until deadline: Date) async throws { current = deadline }
}
```

A `FakeClock` lets you write deterministic tests for code that schedules work, expires caches, or debounces input. The same pattern applies to `URLSession` (wrap in a `HTTPClient` protocol), `FileManager` (wrap in a `FileStore` protocol), and so on. Keep the protocol surface narrow to what the caller actually uses.

## UI tests with XCUIApplication

UI tests launch the app in a subprocess and drive it through the accessibility API. They are slow and prone to flakes. Reserve them for high-value flows: launch, document open, primary command path.

```swift
final class LaunchUITests: XCTestCase {
    func testLaunchAndOpenPreferences() {
        let app = XCUIApplication()
        app.launch()
        app.menuBars.menus["MyApp"].menuItems["Settings\u{2026}"].click()
        XCTAssert(app.windows["Settings"].waitForExistence(timeout: 2))
    }
}
```

Menu item titles contain the proper horizontal ellipsis character (U+2026), not three periods — if you type `"Settings..."` the match fails silently. Prefer `waitForExistence(timeout:)` over polling, and set accessibility identifiers on key views so locators don't depend on localized text.

## Test targets in Package.swift and Xcode

In SwiftPM, declare a `.testTarget` that depends on the library being tested.

```swift
// Package.swift
.testTarget(
    name: "MyAppTests",
    dependencies: ["MyAppCore"],
    path: "Tests/MyAppTests"
)
```

Xcode projects use `.xctest` bundles as test hosts; the app target is set as the host application for UI tests so `XCUIApplication()` knows what to launch. Keep as much logic as possible in a plain SwiftPM library target — it builds and tests faster than driving everything through the app's `.xctest` bundle.

## Testing NSDocument and NSViewController

Logic that lives on a view controller can be tested without launching the UI. Instantiate the controller, force view loading, and assert against its exposed state.

```swift
@MainActor
func testInspectorUpdatesOnSelection() throws {
    let vc = InspectorViewController()
    vc.loadView()
    vc.viewDidLoad()
    vc.selection = [Note(id: UUID(), title: "A")]
    XCTAssertEqual(vc.titleField.stringValue, "A")
}
```

For `NSDocument`, construct the document via its data initializer (`init(data:ofType:)`) rather than going through `NSDocumentController`. You get a fully configured document without touching the filesystem or window server.

## Performance tests

`XCTestCase.measure { }` runs a block repeatedly and records timing baselines. Use it to guard hot paths against regression.

```swift
func testIndexingPerformance() {
    let repo = TestRepo.large()
    measure {
        _ = Indexer().indexAll(repo)
    }
}
```

CI performance metrics are flaky in virtualized runners. Treat `measure` results as useful on developer machines and on dedicated hardware tiers, and do not gate PRs on absolute numbers from shared CI. For finer-grained control, pass an array of `XCTMetric` values to `measure(metrics:block:)`.

## OSLog and Logger

`Logger` (from `import os`) is the modern logging API on macOS. It replaces `print` and the C-style `os_log`. Log calls are free when disabled, preserve type information, and integrate with Console.app and `log show`.

```swift
import os

let logger = Logger(subsystem: "com.example.MyApp", category: "sync")

logger.info("Starting sync")
logger.error("Sync failed: \(error.localizedDescription, privacy: .public)")
```

String interpolations in `Logger` calls are redacted to `<private>` in release builds by default. Opt into `.public` only for values that are safe to expose (non-PII, non-secret). The available privacy markers are:

- `.public` — value is visible in all builds
- `.private` — value is redacted in release (and in shipped logs), visible in debug
- `.auto` — the default; the compiler picks based on the interpolated type

Use one `Logger` per subsystem/category pair and store it as a `let` at file scope or on the type. Creating a new `Logger` per call is fine — it is cheap — but named loggers make Console.app filters readable.

## Signposts for Instruments

`OSSignposter` (from `import os`) marks intervals that show up in Instruments' Points of Interest track. Use it to measure spans that cross function boundaries.

```swift
let signposter = OSSignposter(subsystem: "com.example.MyApp", category: "perf")

let state = signposter.beginInterval("indexRepo", id: signposter.makeSignpostID())
defer { signposter.endInterval("indexRepo", state) }

try await indexer.indexAll()
```

Signposts are cheap enough to leave in production builds. They only cost time when a profiler is attached. Use them for anything you want to correlate with frame drops, CPU spikes, or allocation bursts in Instruments.

## Instruments profiling

Launch Instruments from Xcode via **Product → Profile** (`Cmd+I`). The templates you will actually use:

| Template            | Use when...                                                            |
| ---                 | ---                                                                    |
| Time Profiler       | Finding CPU hotspots and hot call stacks                               |
| Allocations         | Tracking live memory, object counts, allocation bursts                 |
| Leaks               | Finding retain cycles and abandoned memory                             |
| System Trace        | Diagnosing thread contention, scheduler stalls, syscalls               |
| Metal System Trace  | GPU frame timing, encoder stalls, drawable wait                        |
| SwiftUI             | View update reasons and frequency; finding unnecessary invalidations   |

Run Instruments against a release build whenever possible — debug builds have different inlining, safety checks, and allocator behavior. For GPU-specific work, see `advanced-rendering.md`.

## Logging configuration for Console.app

Logs emitted via `Logger(subsystem:category:)` appear in Console.app and in the `log` CLI.

- **Console.app** — filter by subsystem (e.g. `com.example.MyApp`) to scope to your app's output. Use the "Info" and "Debug" toggles in the toolbar to include lower-level messages; by default only `notice` and above are shown.
- **Exported diagnostics** — users can export a filtered log via Console.app → Edit → Copy. Direct bug reporters to this flow rather than asking them to re-run with a debug build.
- **Command line** — `log show --predicate 'subsystem == "com.example.MyApp"' --info --last 1h` queries historical logs. Add `--debug` to include debug-level messages. The `log stream` variant tails live.

For privacy, remember that anything you log with `.public` is persisted in the unified log and can be collected by `sysdiagnose`.

## Crash reporting options

- **Apple's TestFlight / App Store crash reports** — automatic for apps distributed through the App Store or TestFlight. Symbolicated in **Xcode → Window → Organizer → Crashes** when you have App Store Connect access. Requires uploaded dSYMs.
- **MetricKit** (`MXMetricManager`) — an in-app API for receiving daily metric and diagnostic payloads directly from the system. Subscribe an `MXMetricManagerSubscriber` and handle `didReceive(_ payloads:)` and `didReceive(_ diagnosticPayloads:)` to log or forward crash, hang, and CPU-exception reports. Works for sandboxed and non-sandboxed apps.
- **Third-party SDKs** — Sentry, Bugsnag, and Firebase Crashlytics all ship macOS SDKs with crash capture and symbol upload. Pick one based on retention, pricing, and privacy policy; the integration surface is small (initialize early in `NSApplicationDelegate.applicationDidFinishLaunching`).

For direct-distribution apps (Sparkle-based, not App Store), combine `MetricKit` for first-party signal with a third-party SDK for symbolicated stack traces. For App Store apps, Xcode Organizer plus `MetricKit` often covers the need without a third-party dependency.

## Common pitfalls

- **Leaking secrets into `Logger` calls.** Default privacy is `.auto`, but complex values may fall back to `.public`. When in doubt, interpolate with `\(value, privacy: .private)` or don't log the field.
- **Tests that depend on real network or filesystem state.** Inject a fake at the boundary. Anything talking to `example.com` in a unit test is a bug waiting for an offline CI run.
- **`XCTestExpectation` for code that could `await`.** Expectations add noise and mask cancellation behavior. Use `async` tests.
- **UI tests that depend on absolute screen positions.** Layout changes, dynamic type, and window server differences make pixel-coordinate tests flaky. Drive via accessibility identifiers and element queries.
- **Ignoring `MetricKit` payloads.** The system already ships you hang reports, CPU-exception reports, and disk-write metrics; collecting them costs little and surfaces regressions you would otherwise miss.
- **Debug `logger.info` calls in hot paths.** Even with `.private` interpolation, argument formatting and the unified-log round trip have a cost. Use `logger.debug` for verbose messages — it compiles out in release unless explicitly enabled — and remove or gate anything in a per-frame loop.
- **Force-unwrapping in tests.** `try XCTUnwrap(value)` reports a clean failure; `value!` crashes the test runner and kills the suite.
- **Running UI tests on every PR.** They are slow enough to dominate CI time and flaky enough to train engineers to ignore red. Run them nightly or on release branches, and keep the unit suite fast.

## References

- **CodeEdit** and **CotEditor** (see `reference-repos.md`) — study their test targets for real-world XCTest patterns on document-based apps.
- Apple documentation — `Logger`, `OSSignposter`, `MXMetricManager`, `XCTestCase`, `XCUIApplication`; verify signatures against the current SDK.
- Matt Massicotte's blog (`https://www.massicotte.org/`) — Swift concurrency and testing under structured concurrency.
- `references/system-integration.md` — for patterns on testing XPC services and privileged helpers.
- `references/advanced-rendering.md` — for Metal-specific profiling via the Metal System Trace template.
- `references/anti-patterns.md` — cross-check against the full anti-pattern list before shipping.
