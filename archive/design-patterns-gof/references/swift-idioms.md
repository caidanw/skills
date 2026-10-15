# GoF patterns in modern Swift (Swift 5.10 / Swift 6 / iOS 17+ / macOS 14+)

Swift is a multi-paradigm language whose type system, concurrency model, and standard
library erase or transform most of the 23 GoF patterns. The patterns that survive keep
their *name* as vocabulary but almost never keep their *class diagrams*. The patterns
that don't survive are either absorbed into language features (`enum` with associated
values, `@resultBuilder`, `Codable`, actors, `@Observable`), framework machinery (SwiftUI's
view tree, Combine, `AsyncSequence`, `UIResponder` chain), or simply deleted because
Swift's value semantics and copy-on-write made them redundant.

This file is Swift-specific guidance. It assumes you already understand the generic
pattern from its own reference file. Treat classical Java/C++ implementations in Swift
as a **smell** unless explicitly justified — they are almost always ceremonial OO
imported from Objective-C or Java that newer Swift code should avoid.

The spine of this file:

- **Verdict**: idiomatic? (yes / partially / rarely / almost never)
- **Swift replacement**: the language feature or framework that subsumes it
- **Code sketch**: what the Swift-native form looks like
- **In the SDK**: where Apple's own frameworks already express the pattern

---

## Creational (5)

### Abstract Factory — **rarely**

**Swift replacement**: protocol with `associatedtype` + generics; often dependency
injection via a struct holding closures. SwiftUI's `EnvironmentValues` and `@Environment`
do the "swap a family of implementations at a subtree" job declaratively.

For production / preview / test variants, hold a `struct` of closures rather than a
class hierarchy — it composes and mocks without subclassing.

```swift
struct UserClient {
    var fetch: @Sendable (User.ID) async throws -> User
    var save: @Sendable (User) async throws -> Void
}
extension UserClient {
    static let live = UserClient(fetch: { _ in /* URLSession */ fatalError() },
                                 save: { _ in })
    static let preview = UserClient(fetch: { _ in .mock }, save: { _ in })
}
```

**In the SDK**: `URLSessionConfiguration` returns `.default`, `.ephemeral`, `.background(_:)`
— different configured families behind one API. Point-Free's Composable Architecture
popularised the closure-struct flavour and it is now the de facto iOS idiom.

### Builder — **yes, transformed into `@resultBuilder` DSLs**

**Swift replacement**: `@resultBuilder` (SwiftUI `ViewBuilder`, `SceneBuilder`,
`RegexBuilder`, `MapContentBuilder`, SwiftSyntax, `AccessoryWidgetGroup`). Fluent
Java-style builders with `.setX().setY().build()` exist but read as non-idiomatic; prefer
parameter labels with defaults, trailing-closure DSLs, or `@resultBuilder`. The strongest
form of Builder in Swift is **typestate** (see meta-patterns) where the compiler refuses
to call `build()` until required fields are set.

```swift
@resultBuilder
enum StringBuilder {
    static func buildBlock(_ parts: String...) -> String { parts.joined(separator: " ") }
    static func buildOptional(_ part: String?) -> String { part ?? "" }
    static func buildEither(first: String) -> String { first }
    static func buildEither(second: String) -> String { second }
}

func sentence(@StringBuilder _ body: () -> String) -> String { body() }

let s = sentence {
    "Hello"
    "world"
    if Bool.random() { "today" }
}
```

**In the SDK**: `ViewBuilder`, `SceneBuilder`, `ToolbarContentBuilder`, `CommandsBuilder`,
`RegexComponentBuilder`, `MapContentBuilder`, `AttributeScopes`, `AccessoryWidgetGroup`.
See the [Swift by Sundell deep dive](https://www.swiftbysundell.com/articles/deep-dive-into-swift-function-builders/)
and [SwiftLee's result builders article](https://www.avanderlee.com/swift/result-builders/).

### Factory Method — **yes, as static functions / failable inits / enum cases**

**Swift replacement**: static functions, `enum` static members, failable `init?`, or
protocol static requirements. The full GoF "subclass decides concrete type" form is
almost never right in Swift — single inheritance plus value types make it awkward. Prefer
free functions or enum static members (`Color.red`, `URL.documentsDirectory`).

```swift
extension URL {
    static func user(id: UUID) -> URL {
        .init(string: "https://api.example.com/users/\(id)")!
    }
}
// vs. a UserURLFactory class — don't.
```

**In the SDK**: `UIImage(systemName:)`, `URL(string:)`, `Array(repeating:count:)`,
`Measurement(value:unit:)`, `AttributedString(markdown:)`. Static members on types
(`UIColor.systemRed`, `Font.body`) are the idiomatic Swift factory.

### Prototype — **almost never**

**Swift replacement**: **value semantics + copy-on-write**. Structs are copied on
assignment; `Array`, `Dictionary`, `Set`, `String` use copy-on-write (COW) buffers so the
copy is `O(1)` until mutation triggers `isKnownUniquelyReferenced`-guarded buffer
duplication. The entire reason GoF needs Prototype — "construction is expensive, copy is
cheap" — is the *default behavior* in Swift. `NSCopying` survives only for Foundation/AppKit
reference types that predate Swift.

```swift
struct SceneNode { var transform: Transform; var children: [SceneNode] }
var a = SceneNode(...); var b = a           // constant-time copy
b.transform.translate(x: 10)                 // COW; only now does the storage split
```

**In the SDK**: `Array`, `String`, `Dictionary`, `Set`, `Data` — all COW. `NSCopying` /
`NSMutableCopying` are the ObjC-era Prototype, still seen on `NSAttributedString`,
`NSParagraphStyle`, `UIBezierPath`, etc. In Swift-first code, write value types and stop
thinking about Prototype. If you need COW for a big struct, wrap a class in a
`isKnownUniquelyReferenced` check (or reach for the [Swift-CowBox macro](https://github.com/Swift-CowBox/Swift-CowBox)).

### Singleton — **almost never; use a global actor or injected client**

**Swift replacement**: in Swift 6, classical `static let shared = Foo()` with mutable
state is non-`Sendable` and a concurrency hazard. The replacement hierarchy, from best
to worst:

1. **Inject it.** `struct AppDependencies { var api: APIClient; var db: Database }`.
2. **`@MainActor` final class** with `static let shared` — the main actor serializes
   access, preserves synchronous call-sites, and compiles cleanly under strict concurrency.
   Matt Massicotte's
   [Singletons with Swift Concurrency](https://www.massicotte.org/singletons/) argues
   this is usually the right first move.
3. **Custom `@globalActor`** when the domain is genuinely off the main thread (image
   decoding, database, audio engine).
4. **`actor`** only if operations need atomic isolation and can't live on an existing actor.
5. **`@unchecked Sendable` with a lock** if the type is already thread-safe (serial queue,
   `OSAllocatedUnfairLock`).

```swift
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private var cache: [URL: UIImage] = [:]
    private init() {}
    func image(for url: URL) -> UIImage? { cache[url] }
}
```

**In the SDK**: `FileManager.default`, `UserDefaults.standard`, `NotificationCenter.default`,
`URLSession.shared`, `Bundle.main` — all ObjC-era singletons. `MainActor` *itself* is
literally `public static let shared = MainActor()` in the standard library. Modern Apple
APIs (`SwiftData`, `@Observable`, `Observation.Observations`) prefer injection and
environment, not singletons.

---

## Structural (7)

### Adapter — **yes, but trivial**

**Swift replacement**: `extension` + conformance on the existing type (retroactive
conformance), or a thin wrapping struct. No abstract adapter class is needed. `Codable` is
a generalised adapter between domain types and serialisation formats and is so cheap you
never hand-write the ObjC-era `NSCoding` variant.

```swift
extension OldDate: CustomCoordinateConvertible {
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}
```

**In the SDK**: `Codable` (types "adapt" to `Encoder`/`Decoder`); `AnyPublisher`,
`AnyView`, `AnyHashable` are type-erasing adapters; `NSNumber ↔ Int/Double` via `as`;
`String.UTF8View` / `String.UnicodeScalarView` adapt a String to sequences of different
elements. Majid's [type-safe networking](https://swiftwithmajid.com/2021/02/10/building-type-safe-networking-in-swift/)
article shows `Request<Response>` as a phantom-typed adapter over `URLRequest`.

### Bridge — **partially; usually protocol + generic**

**Swift replacement**: protocol as the abstraction, generic parameter (or `some Protocol`)
as the implementation slot. The "two parallel hierarchies joined by composition" of GoF
collapses to one protocol and one generic type. SwiftUI `View` + `ViewModifier` is the
living example — `View` is the abstraction, the view's concrete body is the
implementation, modifiers compose behaviour without subclassing.

```swift
protocol Renderer { func draw(_ shape: some Shape) }
struct ShapeView<R: Renderer> { var renderer: R; var shape: any Shape }
```

**In the SDK**: `View` + `ViewModifier`; `URLProtocol` (bridges `URLRequest` to
transport); `NSFetchRequest` + `NSPersistentStoreCoordinator` (domain vs. store); Core
Graphics' `CGContext` bridging drawing to backing store (PDF, bitmap, layer).

### Composite — **yes, as recursive `struct` or `enum`**

**Swift replacement**: recursive `struct` holding `[Self]`, or `indirect enum` for ASTs.
Protocol with recursive containment works but is less idiomatic than an enum when the
tree is closed. SwiftUI's entire view tree is a Composite where every `View` has a
`body: some View` and that body is another composite.

```swift
indirect enum Expr {
    case literal(Int)
    case add(Expr, Expr)
    case mul(Expr, Expr)
    func eval() -> Int {
        switch self {
        case .literal(let n): return n
        case .add(let l, let r): return l.eval() + r.eval()
        case .mul(let l, let r): return l.eval() * r.eval()
        }
    }
}
```

**In the SDK**: SwiftUI `View` tree, `Scene`, `Menu`, `ToolbarItem`; `CALayer` sublayers;
`NSViewController` child hierarchy; SwiftSyntax's entire node graph. `indirect enum` is
the idiomatic way to build compiler-like ASTs — see
[Swift's enum associated values guide](https://www.splinter.com.au/2019/04/10/swift-state-machines-with-enums/).

### Decorator — **yes, as `ViewModifier` and property wrappers**

**Swift replacement**: for views, `ViewModifier` chaining (`.padding().background(.red).shadow(...)`).
For properties, **property wrappers** (`@Published`, `@State`, `@AppStorage`,
`@Environment`) act as per-property decorators, each adding storage/observation/persistence
behaviour to a plain property. For generic "wrap and intercept" flows, async middleware is
usually `async` closures chained around a base call. Note: property wrappers generally
**do not compose by stacking** (`@A @B var x` is usually a compile error); compose by
*embedding* one `DynamicProperty`-conforming wrapper inside another — see
[Donny Wals on custom property wrappers](https://www.donnywals.com/writing-custom-property-wrappers-for-swiftui/).

```swift
Text("Hello")
    .padding()
    .background(.yellow)
    .clipShape(.capsule)
    .shadow(radius: 4)          // each modifier decorates the previous View
```

**In the SDK**: every SwiftUI view modifier; `@Published`, `@State`, `@AppStorage`,
`@SceneStorage`, `@Environment`, `@FocusState`, `@FetchRequest`; `URLProtocol` subclasses
decorating network behaviour; Combine's operator chain on `Publisher`.

### Facade — **yes, extremely common**

**Swift replacement**: a `struct` or `final class` exposing a small domain API over a
noisy subsystem. This is the *one* GoF pattern that is as alive in Swift as in any OO
language — SDK clients, networking layers, Core Data wrappers, analytics SDKs. Keep the
facade narrow and domain-shaped (`fetchUser(id:)`) rather than generic (`request(:)`) or
it turns into a god object.

```swift
final class PhotoAPI {
    private let session: URLSession = .shared
    func photos(for user: User.ID) async throws -> [Photo] {
        let (data, _) = try await session.data(from: .photos(user: user))
        return try JSONDecoder().decode([Photo].self, from: data)
    }
}
```

**In the SDK**: `URLSession.shared.data(from:)` (one line hiding all of CFNetwork);
`NSPersistentContainer` (hiding `NSPersistentStoreCoordinator`, `NSManagedObjectModel`,
context plumbing); SwiftData's `ModelContainer`; `PHPhotoLibrary`; CloudKit's
`CKDatabase` methods over operation-queue APIs; `CryptoKit`'s `SymmetricKey`
over CommonCrypto.

### Flyweight — **rarely, mostly in text/graphics**

**Swift replacement**: for strings, `String` interning is partial (small string
optimisation inlines short strings); for fonts, `UIFont.systemFont(ofSize:)` and `Font`
are already deduplicated. SwiftUI `EnvironmentValues` flow shared state down the tree
without per-view copies — a conceptual flyweight of context values. For hand-rolled
pooling you want a dictionary keyed on identity and value-semantics-protected storage.

```swift
final class GlyphAtlas {          // one CGImage per (font, glyph) pair
    private var cache: [GlyphKey: CGImage] = [:]
    func image(for key: GlyphKey, make: () -> CGImage) -> CGImage {
        if let hit = cache[key] { return hit }
        let img = make(); cache[key] = img; return img
    }
}
```

**In the SDK**: `UIFont` caches per configuration; `CATextLayer` / CoreText glyph caches;
SwiftUI `Image(systemName:)` deduplicates SF Symbol rasters; `NSColor.labelColor` etc.
are singletons-per-semantic-role.

### Proxy — **yes, several distinct Swift forms**

**Swift replacement**: four common shapes, pick the one that matches intent.

1. **Virtual / lazy**: `lazy var`, or wrapping in a SwiftData/Core Data managed object
   (faulting is a built-in virtual proxy).
2. **Protection**: an `actor` is a protection proxy by construction — access must go
   through an isolated boundary.
3. **Remote**: gRPC/URLSession stubs; CloudKit's record references.
4. **Smart / transparent wrapper**: `@dynamicMemberLookup` + `KeyPath` forwards all member
   access to an inner value while letting you intercept reads and writes. This is the
   killer Swift-specific Proxy form because it keeps compile-time safety.

```swift
@dynamicMemberLookup
struct Tracked<Value> {
    private var value: Value
    var reads = 0
    init(_ value: Value) { self.value = value }
    subscript<T>(dynamicMember kp: KeyPath<Value, T>) -> T {
        mutating get { reads += 1; return value[keyPath: kp] }
    }
}
```

**In the SDK**: Core Data / SwiftData faulting (lazy proxy over the store); `NSProxy`
(ObjC-era); `AnyPublisher` (type-erasing proxy over `Publisher`); `URLProtocol` (protection
+ remote proxy); `KeyPath` itself; TCA's `Store<State,Action>` is a `@dynamicMemberLookup`
proxy over state. See [SwiftLee on dynamic member lookup](https://www.avanderlee.com/swift/dynamic-member-lookup/).

---

## Behavioral (11)

### Chain of Responsibility — **yes, both SDK-provided and DIY**

**Swift replacement**: the UIKit/AppKit `UIResponder`/`NSResponder` chain is a literal
GoF implementation baked into the SDK. In SwiftUI, the equivalent is **environment-based
event forwarding**: a child view pulls a handler closure out of `@Environment`, calls it,
and if the current responder can't handle it, it calls the closure it previously read
from the environment (its parent's handler). See Emilio Peláez's
[Building a Responder Chain in SwiftUI](https://betterprogramming.pub/building-a-responder-chain-using-the-swiftui-view-hierarchy-2a08df23689c).
For server-side middleware, write an array of `async` handlers, each taking `next`.

```swift
typealias Middleware = (Request, _ next: (Request) async throws -> Response) async throws -> Response
func run(_ req: Request, through mws: [Middleware], final: (Request) async throws -> Response) async throws -> Response {
    var iter = mws.makeIterator()
    func next(_ r: Request) async throws -> Response {
        if let mw = iter.next() { return try await mw(r, next) } else { return try await final(r) }
    }
    return try await next(req)
}
```

**In the SDK**: `UIResponder`/`NSResponder` chain (`target(forAction:withSender:)`),
`UIMenuBuilder`, `KeyCommand` routing, Vapor/Hummingbird middleware stacks.

### Command — **yes, but usually a closure or `async` func, sometimes an enum**

**Swift replacement**: closures and `async` functions cover 90%. When you need serialisation,
undo, or replay, reach for:

1. **Closures** for fire-and-forget UI callbacks (`Button(action:)`).
2. **`enum Action` with associated values** for reducer-style architectures (TCA, Elm,
   Redux).
3. **`UndoManager`** plus a closure pair for undo/redo.
4. **`Operation` / `OperationQueue`** if you need cancellation, dependencies, priority —
   but usually structured concurrency (`async`/`await`, `TaskGroup`) supersedes it.

```swift
enum Action { case increment, setName(String), loadUser(id: UUID) }
func reduce(_ state: inout State, _ action: Action) -> Effect { ... }
```

**In the SDK**: `UIAction` / `UIMenuElement`; `Operation` / `NSInvocationOperation`;
`UndoManager.registerUndo`; SwiftUI `Button(action:)`; every `async` function is a
deferred command.

### Interpreter — **partially, as `indirect enum` + `func eval()`**

**Swift replacement**: `indirect enum` for the AST plus a recursive `eval` function
(pattern matched with `switch`). For real parsers, use `RegexBuilder` (itself a DSL built
on `@resultBuilder`) or combinator libraries. SwiftUI's view tree is effectively an
interpreted DSL.

```swift
indirect enum JSON {
    case null, bool(Bool), number(Double), string(String)
    case array([JSON]), object([String: JSON])
}
// parse/eval as recursive functions over cases
```

**In the SDK**: `RegexBuilder` (a Swift-native regex DSL); `NSPredicate` (stringly-typed,
avoid); `Foundation.Formatter`; `Expression` evaluators in SwiftUI's query predicates.

### Iterator — **yes, built in; `AsyncSequence` for the async case**

**Swift replacement**: `Sequence` + `IteratorProtocol` (and the compiler synthesises
iterators for `for` loops). For async, `AsyncSequence` + `AsyncIteratorProtocol` with
`for await ... in`. For callback-based producers, wrap them in `AsyncStream` /
`AsyncThrowingStream` with a continuation. You almost never hand-write an iterator; you
conform or use a stdlib combinator. See
[SwiftLee on AsyncSequence](https://www.avanderlee.com/concurrency/asyncsequence/).

```swift
func lines(in url: URL) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            for try await line in url.lines { continuation.yield(line) }
            continuation.finish()
        }
    }
}
```

**In the SDK**: `Array`, `Set`, `Dictionary`, `String`, `Range` conform to `Sequence`;
`URL.lines`, `FileHandle.bytes`, `NotificationCenter.notifications(named:)`,
`AsyncChannel`, `TaskGroup` all conform to `AsyncSequence`; SwiftData `FetchDescriptor`
results.

### Mediator — **partially; MVVM, stores, and @Observable models**

**Swift replacement**: the "central hub coordinating peers" role is played by **view
models** (MVVM), **stores** (TCA / Redux-style), or `@Observable` coordinators in SwiftUI.
Peer views observe the store's state and send actions; they never talk directly to each
other. In SwiftUI, `@Environment` and `@EnvironmentObject` let a mediator be injected at
a subtree root.

```swift
@Observable
final class CheckoutModel {
    var cart: Cart = .empty
    var payment: PaymentState = .idle
    func addItem(_ item: Item) { cart.add(item); recomputeTotals() }
    func pay() async { payment = .processing; /* ... */ }
}
```

**In the SDK**: `NSNotificationCenter` is the classic dumb-mediator; `@Observable` models
(iOS 17+), SwiftUI `App` scene + `@Environment`, Combine subjects. `NSWindowController`
historically mediated between `NSDocument` and its views.

### Memento — **partially; value types + `UndoManager` or reducer snapshots**

**Swift replacement**: take a value-type snapshot (structs copy on assignment — that's
Memento for free) and either stash it on `UndoManager` or keep a history stack in a
reducer. For SwiftUI, `@SceneStorage` / `@AppStorage` serialise a memento to disk/defaults.
`Codable` lets you snapshot any value into `Data` and restore it transactionally.

```swift
var history: [AppState] = []
func mutate(_ f: (inout AppState) -> Void) {
    history.append(state)      // snapshot — O(1) due to value semantics / COW
    f(&state)
}
func undo() { if let prev = history.popLast() { state = prev } }
```

**In the SDK**: `UndoManager`; SwiftUI `@SceneStorage` and `@AppStorage` for per-scene /
per-app mementos; `NSDocument` autosave; SwiftData transaction rollback;
`Transactions` + time-travel debugging in TCA.

### Observer — **yes, but the idiom flipped in iOS 17 to `@Observable`**

**Swift replacement**: iOS 17+ / macOS 14+ the idiomatic choice is the
[`@Observable` macro](https://developer.apple.com/documentation/Observation) from the
Observation framework. Views auto-subscribe only to the properties they *actually read*,
which is strictly better than `@Published` + `ObservableObject` + Combine (which
re-renders on any `@Published` change). Use:

- **`@Observable`** class for model state observed by SwiftUI views (iOS 17+).
- **`Observations` `AsyncSequence`** for long-running observation outside SwiftUI (Swift 6.2 / OS 26+).
- **`NotificationCenter.MainActorMessage` / `AsyncMessage`** for type-safe broadcasts (Swift 6.2).
- **Combine / `@Published`** for legacy code or pre-iOS-17 targets.
- Manual `didSet` / delegate protocols for simple one-to-one notification.

```swift
@Observable
final class Counter { var count = 0; func inc() { count += 1 } }

struct CounterView: View {
    @State var counter = Counter()   // @State caches the @Observable across redraws
    var body: some View { Text("\(counter.count)").onTapGesture { counter.inc() } }
}
```

**In the SDK**: `@Observable` (Observation framework); Combine `Publisher` / `@Published`;
`NotificationCenter`; KVO (`@objc dynamic` + `observe(_:options:changeHandler:)`);
SwiftUI `@Binding` is a two-way observer. See
[Donny Wals on @Observable](https://www.donnywals.com/observable-in-swiftui-explained/).

### State — **yes, as `enum` with associated values (+ optionally protocol dispatch)**

**Swift replacement**: model the state as an `enum` with associated values so illegal
states are unrepresentable. Drive transitions from an `event` enum switched on the
current state. For UI, mirror it to a `@State` / `@Observable` property. The GoF
"state objects with shared protocol" form is only worth reaching for when each state has
genuinely heavy behaviour *and* you need polymorphic dispatch — otherwise a switch over
the enum in one function is clearer. See
[State Machines in Swift using enums](https://www.splinter.com.au/2019/04/10/swift-state-machines-with-enums/).

```swift
enum LoadState<T> {
    case idle, loading, loaded(T), failed(Error)
}

enum Event { case start, finish(Data), fail(Error), reset }
func reduce<T: Decodable>(_ s: inout LoadState<T>, _ e: Event) throws {
    switch (s, e) {
    case (.idle, .start), (.failed, .start): s = .loading
    case (.loading, .finish(let d)): s = .loaded(try JSONDecoder().decode(T.self, from: d))
    case (.loading, .fail(let err)): s = .failed(err)
    case (_, .reset): s = .idle
    default: break   // ignore invalid transition
    }
}
```

**In the SDK**: `Result<Success, Failure>` (two-state enum); `URLSessionTask.State`;
`CLAuthorizationStatus`; every "status" enum. TCA reducers are pure state-machine
functions over `State` + `Action`.

### Strategy — **yes, but it's usually just a function**

**Swift replacement**: pass a function (or `some Protocol` if you need associated types).
The GoF class-per-strategy form is ceremonial overkill in Swift. For heterogeneous storage
use `any Protocol`; for hot paths prefer `some Protocol` or a generic to avoid existential
overhead.

```swift
struct Sorter<T> { var compare: (T, T) -> Bool }
extension Sorter where T: Comparable {
    static var ascending:  Sorter { .init(compare: <) }
    static var descending: Sorter { .init(compare: >) }
}
```

**In the SDK**: `Array.sorted(by:)`, `filter`, `map`, `reduce` — all take a strategy
closure; `JSONDecoder.KeyDecodingStrategy`, `.DateDecodingStrategy`; `NumberFormatter`
configuration; SwiftUI `LayoutValueKey`/`Layout` protocol swappable layouts.

### Template Method — **almost never; prefer protocol extensions or Strategy**

**Swift replacement**: **protocol + protocol extension** gives default implementations
without forcing inheritance. If the "fixed skeleton, variable steps" shape is genuinely
useful, model the fixed parts as a free function taking closures (Strategy) and leave the
variable parts as parameters. Classical Template Method pulls you back into single
inheritance and forbids value types — fight it.

```swift
protocol Renderable {
    func willRender()
    func render()
    func didRender()
}
extension Renderable {
    func willRender() {}; func didRender() {}    // safe defaults
    func performRender() { willRender(); render(); didRender() }
}
```

**In the SDK**: `Sequence` (default `map`/`filter`/`reduce` implementations over `next`);
`Collection` protocol hierarchy; `View`'s `body` + modifiers; `NSDocument` lifecycle
callbacks (the ObjC-era holdout).

### Visitor — **rarely; prefer `switch` over a sealed enum**

**Swift replacement**: pattern matching on an `enum` with exhaustiveness checking. Swift's
compiler will tell you when a new case breaks existing `switch` statements, which is the
entire point of Visitor's "double dispatch" in languages without sum types. `Codable`'s
`Encoder` / `Decoder` architecture is a framework-level Visitor and is the one place you'll
see the shape in stdlib form. See
[the Swift Forums thread on switch vs visitor](https://forums.swift.org/t/choosing-between-switch-over-types-and-visitor-pattern/59744).

```swift
enum Shape { case circle(r: Double); case rect(w: Double, h: Double) }
extension Shape {
    var area: Double {
        switch self {
        case .circle(let r): return .pi * r * r
        case .rect(let w, let h): return w * h
        }
    }
}
```

**In the SDK**: `Codable` — `encode(to:)` / `init(from:)` is a visitor accepting an
`Encoder` / `Decoder`; SwiftSyntax's `SyntaxVisitor` (generated-code Visitor, the ObjC
shape because AST visitors benefit from dispatch tables); `NSNumber` CF bridging.

---

## Swift-specific meta-patterns (not in GoF)

These are the *actual* patterns modern Swift code reaches for. Most of them subsume
several GoF patterns at once.

### Protocol-oriented programming (POP)

"Start with a protocol, not a class" (Abrahams, WWDC 2015). Protocols model *acts-as-a*
relationships, compose freely, work for value types, and support **retroactive
conformance** — you can add a protocol to a type you don't own, something class inheritance
can never do. This single capability kills most uses of Adapter, Bridge, Template Method,
and even Abstract Factory. Reserve class inheritance for (a) Objective-C interop,
(b) `NSObject`-based frameworks (UIKit view controllers), (c) cases where you genuinely
need reference identity and stored properties shared across subclasses. See
[Swift by Sundell / SwiftLee material on POP](https://www.swiftbysundell.com/articles/)
and [objc.io's Protocols & Class Hierarchies](https://talk.objc.io/episodes/S01E29-protocols-class-hierarchies).

### `some` (opaque) vs `any` (existential)

- **`some Protocol`** = "the same single concrete type, hidden from the caller"; zero
  existential overhead, works with associated types. Use by default, especially for return
  types (`some View`, `some Publisher<Int, Never>`, `some Sequence<Int>`).
- **`any Protocol`** = "any type conforming, may vary at runtime"; required for
  heterogeneous arrays, stored properties whose type can change, protocol values sent
  across module boundaries. Costs a witness table and pointer indirection.
- **Generic `<T: Protocol>`** when you want the caller to choose.

Rule of thumb (WWDC 2022, *Design protocol interfaces in Swift*): write `some` by default,
switch to `any` only when storage flexibility demands it. Since Swift 6, `any` is **required**
at use sites for existentials; bare protocol names are errors.

### `@resultBuilder` as "DSL Builder"

Subsumes the GoF Builder pattern for any nested hierarchical construction. SwiftUI
(`ViewBuilder`), `RegexBuilder`, `MapContentBuilder`, SwiftSyntax, and custom DSLs (HTML,
AutoLayout constraints, test fixtures) all use it. `buildPartialBlock` (SE-0348, Swift 5.7)
removed the factorial overload explosion and is what made `RegexBuilder` possible. When
you'd historically write a fluent builder, ask: would a `@resultBuilder` block read better?

### Typestate with phantom generic parameters

Encode builder state as a phantom generic parameter so the compiler refuses to call
`.build()` until the type parameter says the required fields are set. Swift 5.9's
noncopyable types (`~Copyable`) make this robust by preventing re-use of an earlier state.
See [Swiftology's Typestate article](https://swiftology.io/articles/typestate/) and Majid's
`Request<Response>` networking wrapper.

```swift
struct Request<HasURL, HasMethod> {
    var url: URL?; var method: HTTPMethod?
}
extension Request where HasURL == Void, HasMethod == Void {
    init() { self.url = nil; self.method = nil }
}
extension Request {
    func url(_ u: URL) -> Request<Set, HasMethod> { .init(url: u, method: method) }
    func method(_ m: HTTPMethod) -> Request<HasURL, Set> { .init(url: url, method: m) }
}
extension Request where HasURL == Set, HasMethod == Set {
    func build() -> URLRequest { var r = URLRequest(url: url!); r.httpMethod = method!.rawValue; return r }
}
enum Set {}       // phantom marker
```

### Property wrappers as composable decorators

Per-property behaviour: `@Published`, `@State`, `@StateObject`, `@ObservedObject`,
`@AppStorage`, `@SceneStorage`, `@Environment`, `@FocusState`, `@FetchRequest`,
`@Query` (SwiftData), `@Bindable` (iOS 17+). They *look* like Decorators but **do not
compose by stacking** on a single property — compose by embedding one wrapper inside
another via the `DynamicProperty` protocol. Macros (Swift 5.9+) supersede property
wrappers for more ambitious cross-property transformations.

### Actors + `Sendable` as concurrency-safe Singletons

- `@MainActor final class` with `static let shared` is the simplest safe "singleton" and
  preserves synchronous call-sites.
- Custom `@globalActor` for off-main domain isolation (image processing, database, audio).
- Plain `actor` only when you need atomic operations on non-`Sendable` state that can't
  live on an existing actor.
- `@unchecked Sendable` only for types already thread-safe via a lock / serial queue.

Massicotte's guidance: *"Already thread-safe? `@unchecked Sendable`. Otherwise, `@MainActor`
is likely the best option for both simplicity and performance."*

### `@Observable` replacing manual Observer wiring

The iOS 17+ default. View re-renders are driven by *actual property reads* inside
`body`, not by a coarse `@Published` firehose — zero boilerplate, fewer redundant
redraws. In SwiftUI, pair `@Observable` classes with `@State` (to cache the instance across
view redraws). Swift 6.2's `Observations` `AsyncSequence` extends this outside SwiftUI.

### Structured concurrency replaces Command-for-async

`async let`, `TaskGroup`, `ThrowingTaskGroup`, and `Task { }` replace the `Operation` /
`NSOperationQueue` Command-for-async pattern. `TaskGroup` conforms to `AsyncSequence`,
giving you iteration over concurrent child results. Cancellation is cooperative via
`Task.checkCancellation()` — no ceremony. Use `Operation` only for legacy AppKit/UIKit
integration.

### `Codable` replaces hand-written Adapters

`Codable` + synthesised `Encoder` / `Decoder` conformance replaces NSCoding, JSON
serialisers, and most hand-written Adapter code at serialisation boundaries. For shape
mismatches, pair with Swift Macros (e.g., `ReerCodable`) or property-wrapper adapters
(`CodableWrappers`) rather than hand-writing `CodingKeys` and `init(from:)`. Treat a
custom `Encoder` / `Decoder` implementation as the Visitor-shape escape hatch when you
need format control (Protobuf, CBOR, custom binary).

### `KeyPath` + `@dynamicMemberLookup` for type-safe proxies

`KeyPath<Root, Value>` is a compile-time-checked property reference. Combined with
`@dynamicMemberLookup` it lets you build proxies, lenses, and store wrappers that forward
arbitrary `.member` access to an inner value while keeping autocomplete and type
checking. TCA's `Store<State, Action>.$state` uses this; so do several
validation-wrapper libraries.

### Copy-on-write making Prototype obsolete

Value semantics + COW buffers in `Array`, `Dictionary`, `Set`, `String`, `Data` mean
`var b = a` is constant-time and only diverges on mutation. Don't invent `NSCopying`-style
clone methods for your own structs; they already behave the right way. If you have a big
custom struct and need COW on its private storage, wrap a class and gate mutations on
`isKnownUniquelyReferenced`, or use the
[Swift-CowBox macro](https://github.com/Swift-CowBox/Swift-CowBox).

### `MainActor` and global actors as Singleton replacement

The `MainActor` is *itself* a singleton actor (`public static let shared = MainActor()` in
the stdlib). Instead of building a thread-safe singleton, isolate the type to a global
actor and let the compiler enforce access. This is simpler, faster, and more correct than
locks-on-a-class.

---

## Quick decision card for Swift

| GoF pattern | Reach for… |
|---|---|
| Abstract Factory | Struct-of-closures + `@Environment` injection |
| Builder | `@resultBuilder` DSL, or typestate via phantom generics |
| Factory Method | Static function / failable init / enum static member |
| Prototype | Value semantics + COW (it's automatic) |
| Singleton | `@MainActor`, global actor, or (preferably) dependency injection |
| Adapter | `extension` + retroactive conformance; `Codable` |
| Bridge | Protocol + generic / `some Protocol` |
| Composite | Recursive struct or `indirect enum` |
| Decorator | `ViewModifier` chain; property wrappers |
| Facade | `final class` / `struct` with a narrow, domain-shaped API |
| Flyweight | Identity-keyed cache; `EnvironmentValues` flow |
| Proxy | `lazy var`, `actor`, `@dynamicMemberLookup` + `KeyPath` |
| Chain of Responsibility | `UIResponder`, SwiftUI environment handler forwarding, `async` middleware |
| Command | Closure / `async` function / `enum Action` |
| Interpreter | `indirect enum` + recursive `func eval()`; `RegexBuilder` |
| Iterator | `Sequence`, `AsyncSequence`, `AsyncStream` |
| Mediator | `@Observable` view model / store; `@Environment`-scoped |
| Memento | Value-type snapshot + `UndoManager` / history stack |
| Observer | `@Observable` (iOS 17+); Combine / `@Published` (legacy) |
| State | `enum` with associated values + reducer `switch` |
| Strategy | A closure, occasionally `some Protocol` |
| Template Method | Protocol extension defaults, or skip it |
| Visitor | `switch` on a sealed enum; `Codable` is the framework exemplar |

---

## Sources

- Paul Hudson — [Concurrency quick start](https://www.hackingwithswift.com/quick-start/concurrency), [How to use phantom types](https://www.hackingwithswift.com/plus/advanced-swift/how-to-use-phantom-types-in-swift), [Dynamic Member Lookup](https://www.hackingwithswift.com/articles/55/how-to-use-dynamic-member-lookup-in-swift)
- Antoine van der Leest (SwiftLee) — [Result builders](https://www.avanderlee.com/swift/result-builders/), [AsyncSequence](https://www.avanderlee.com/concurrency/asyncsequence/), [Global actors](https://www.avanderlee.com/concurrency/global-actor/), [Property wrappers](https://www.avanderlee.com/swift/property-wrappers/), [Existential any](https://www.avanderlee.com/swift/existential-any/), [Dynamic Member Lookup](https://www.avanderlee.com/swift/dynamic-member-lookup/)
- John Sundell (Swift by Sundell) — [Result builders deep dive](https://www.swiftbysundell.com/articles/deep-dive-into-swift-function-builders/), [Async sequences, streams, and Combine](https://www.swiftbysundell.com/articles/async-sequences-streams-and-combine/), [Phantom types](https://www.swiftbysundell.com/articles/phantom-types-in-swift/), [Property wrappers](https://www.swiftbysundell.com/articles/property-wrappers-in-swift/), [Dynamic member lookup + key paths](https://www.swiftbysundell.com/tips/combining-dynamic-member-lookup-with-key-paths/)
- Matt Massicotte — [Singletons with Swift Concurrency](https://www.massicotte.org/singletons/)
- Donny Wals — [@Observable in SwiftUI](https://www.donnywals.com/observable-in-swiftui-explained/), [Writing custom property wrappers](https://www.donnywals.com/writing-custom-property-wrappers-for-swiftui/)
- Majid Jabrayilov — [Type-safe networking](https://swiftwithmajid.com/2021/02/10/building-type-safe-networking-in-swift/), [Dynamic member lookup](https://swiftwithmajid.com/2023/05/23/dynamic-member-lookup-in-swift/)
- Swiftology — [Typestate: the new Design Pattern in Swift 5.9](https://swiftology.io/articles/typestate/)
- Emilio Peláez — [Building a Responder Chain in SwiftUI](https://betterprogramming.pub/building-a-responder-chain-using-the-swiftui-view-hierarchy-2a08df23689c)
- Daniel Kennett — [Responder chain interop with SwiftUI](https://ikennd.ac/blog/2024/09/handling-responder-chain-actions-in-swiftui/)
- Apple — [Observation framework](https://developer.apple.com/documentation/Observation), [Migrating from ObservableObject to @Observable](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro), [Design protocol interfaces in Swift (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/110353/), [Write a DSL in Swift using result builders (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10253/)
- Swift Evolution — [SE-0289 Result Builders](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-result-builders.md), [SE-0316 Global Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md), [SE-0335 Existential any](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md), [SE-0252 KeyPath dynamic member lookup](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0252-keypath-dynamic-member-lookup.md)
- [ochococo/Design-Patterns-In-Swift](https://github.com/ochococo/Design-Patterns-In-Swift) — reference repo; note most of its examples are the *classical* Swift form, not the 2025 idiomatic form covered above
- [Splinter Software — State machines with Swift enums](https://www.splinter.com.au/2019/04/10/swift-state-machines-with-enums/)
- [Swift-CowBox macro](https://github.com/Swift-CowBox/Swift-CowBox) — copy-on-write for custom structs
- [objc.io — Protocols & Class Hierarchies](https://talk.objc.io/episodes/S01E29-protocols-class-hierarchies), [Type-Safe File Paths with Phantom Types](https://talk.objc.io/episodes/S01E71-type-safe-file-paths-with-phantom-types)
