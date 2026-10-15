# Protocol-Oriented Programming and the GoF patterns

This file is the companion to `swift-idioms.md`. Where `swift-idioms.md` maps each
GoF pattern to its idiomatic Swift form, this file does the opposite: it starts from
**Protocol-Oriented Programming (POP)** — Dave Abrahams' WWDC 2015 Session 408
thesis — and shows how that single shift in worldview subsumes, transforms, or
invalidates roughly half of the GoF catalogue. It also catalogues the ways POP can
go wrong a decade later, and when a modern Swift codebase should still reach for a
class.

If you've read Abrahams' talk, skim section 1. If you haven't, read it top to
bottom — this is the Rosetta Stone for why Swift design patterns don't look like
Java or C++ design patterns.

---

## 1. The WWDC 2015 thesis (the "Crusty" talk)

### 1.1 The setup — Crusty and his three beefs

Abrahams' 2015 keynote opened with a fictional colleague, **Crusty**, a grizzled
engineer who has seen "every promising new paradigm of the last 40 years" and
doesn't do object-oriented. Apple's saying was ambitious: *"Swift is a
protocol-oriented programming language."*

Crusty's three complaints about classes drive the rest of the talk:

1. **Implicit sharing of mutable state.** *"A hands B some piece of perfectly sober
   looking data, and B thinks, 'Great, conversation over.' But now A and B each have
   their own very reasonable view of the world that just happens to be wrong."* Once
   A mutates the shared reference, B is broken. The downstream cascade — defensive
   copying everywhere, then race conditions across threads, then locks, then
   deadlocks, then more bugs — is the primary indictment of reference types as
   default.
2. **Inheritance is too intrusive.** You can only have one superclass. Subclasses
   depend on **implementation details** of the superclass (the fragile base class
   problem). You inherit stored properties whether you want them or not. The
   relationship between superclass and subclass is hard to change once shipped.
3. **Lost type relationships.** Classical single inheritance can't express *"two
   instances of the same concrete type must interact"*. The pre-POP
   `precedes(other: Ordered) -> Bool` example had to `as!`-cast `other` to the right
   subclass. That cast is a runtime assertion the type system cannot enforce.

### 1.2 The answer — "Don't start with a class. Start with a protocol."

The famous line, quoted out of context, sounds prescriptive. Abrahams' actual
phrasing was conditional:

> *"For example, if you want to write a generalized sort or binary search… don't
> start with a class. Start with a protocol."*

Rob Napier's [retrospective](https://robnapier.net/start-with-a-protocol) is worth
reading precisely because he watched the community (including himself) misapply
the slogan. His correction: *"Write concrete code first. Then work out the
generics."* POP is about **generic algorithms and extensions**, not about
front-loading every type with a protocol it doesn't need.

### 1.3 The Ordered / Number refactor (the on-stage example)

Before (classes):

```swift
class Ordered {
    func precedes(other: Ordered) -> Bool { fatalError("implement me") }
}
class Number: Ordered {
    var value = 0.0
    override func precedes(other: Ordered) -> Bool {
        return self.value < (other as! Number).value   // runtime cast; can crash
    }
}
```

After (protocol with `Self` requirement):

```swift
protocol Ordered {
    func precedes(other: Self) -> Bool              // compiler-enforced homogeneity
}
struct Number: Ordered {
    var value: Double
    func precedes(other: Number) -> Bool { value < other.value }
}
```

The `Self` requirement is the point. It expresses *"whatever concrete type adopts
this protocol, `precedes` takes the **same** concrete type."* No cast, no
`fatalError`, no runtime check. The compiler refuses to let you compare a
`Number` to a `LandscapeNumber` — which is exactly the constraint the domain
wanted.

Abrahams openly flagged the trade: *"Once you add a Self-requirement, it moves the
protocol into a different world. It stops being usable as a type. Collections
become homogeneous instead of heterogeneous. We trade dynamic polymorphism for
static polymorphism, but in return the compiler can optimize much harder."* This
is the **two-worlds** problem that dominates the rest of POP's history (sections
3 and 5 below).

### 1.4 Retroactive modeling — the capability classes cannot match

Abrahams' `Renderer` demo showed extending `CGContext` — a Core Graphics type
Apple owns — to conform to a `Renderer` protocol the developer owns. Class
inheritance can never do this; you cannot retroactively declare *"`CGContext` is
now a subclass of my `Renderer`."* Retroactive conformance makes protocols
**open** in a way class hierarchies are not. This alone kills most uses of
**Adapter** (section 4).

### 1.5 When Abrahams himself said to use a class

The talk is not anti-class. Abrahams explicitly listed when a class is the right
answer: copying doesn't make sense, instance lifetime is tied to external state
(a `TemporaryFile`, a `CGContext`, a socket), instances are write-only sinks, or
the framework you're in (AppKit, UIKit, Core Data) is built around subclassing.
*"It does not make sense to fight the system."* Section 6 picks this up for 2025.

---

## 2. POP's technical mechanisms

Five language features do the work. Understanding which does which disarms most
"protocol soup" mistakes.

### 2.1 Protocol requirements (the contract)

A protocol declares method, property, initializer, and subscript signatures that
any conformer must supply. Unlike abstract classes, there is no implementation
slot in a requirement — no stored properties, no super-call ceremony.

### 2.2 Protocol extensions (default implementations)

`extension` on a protocol provides default implementations that every conformer
inherits unless overridden. This is how you model *"skeleton plus steps"*
(Template Method) without single inheritance and without classes.

```swift
protocol Renderable {
    func render()
}
extension Renderable {
    func willRender() {}
    func didRender() {}
    func performRender() { willRender(); render(); didRender() }  // default skeleton
}
```

Two gotchas:

- **Dispatch**: a method defined **only in the extension** (not declared in the
  protocol) uses **static dispatch** based on the compile-time type, even for a
  protocol value. This is fast but surprising — overriding in a conformer does
  not dispatch polymorphically unless the method is a protocol requirement.
- **Conflict**: a conformer can provide its own implementation and *silently*
  shadow the default. There is no `override` keyword; the compiler does not warn.

### 2.3 Associated types (`associatedtype`) and `Self`

Associated types let a protocol abstract over the *types it is parameterized by*,
not just over methods. `Collection` has `Element` and `Index`. `IteratorProtocol`
has `Element`. `Numeric` has `Magnitude`.

```swift
protocol Container {
    associatedtype Element
    var count: Int { get }
    mutating func append(_ item: Element)
    subscript(i: Int) -> Element { get }
}
```

This is *strictly more expressive* than single inheritance. A class hierarchy
cannot say *"the element type of `self` must be the same as the element type of
the other argument"* — a protocol with `Self` and `associatedtype` can. This is
the capability that lets `Collection`'s algorithms (`map`, `filter`, `reduce`) be
written once and specialized for every conforming type.

### 2.4 Retroactive conformance

Any conformance can be added in an extension, in any module, after the fact:

```swift
// in your code, adapting Apple's CGContext to your Renderer protocol
extension CGContext: Renderer {
    func move(to p: CGPoint) { self.move(to: p) }
    func line(to p: CGPoint) { self.addLine(to: p) }
}
```

Class inheritance has no equivalent. This kills most uses of the GoF Adapter.
(Swift 6 requires the `@retroactive` attribute to make cross-module conformance
explicit and discourage library conflicts.)

### 2.5 Static dispatch and specialization

When the compiler knows the concrete conforming type at the call site — because
you used a generic parameter `<T: Protocol>` or an opaque `some Protocol` — it
**monomorphizes**: generates a specialized copy per concrete type, inlines the
protocol method calls, and optimizes them as if they were direct function calls.
This is the "return for the extra type information" Abrahams promised. The same
code on an `any Protocol` existential pays a witness-table indirection on every
call.

The rule of thumb:

- `some P` / `<T: P>` → static dispatch, specialization, no existential box. Fast.
- `any P` → dynamic dispatch, heap box for values larger than three words,
  witness-table lookup per call. Flexible, slower.

---

## 3. The standard library is the proof

Every argument above is made concrete by the stdlib:

- `Equatable`, `Comparable`, `Hashable`, `Identifiable` — capabilities, not
  identities. A `String`, a `Date`, and a `UUID` are all `Hashable` without
  sharing any ancestor.
- `Sequence` / `IteratorProtocol` — the Iterator pattern, expressed once and
  implemented retroactively by `Array`, `Set`, `Dictionary`, `Range`, and every
  `AsyncSequence`.
- `Collection`, `BidirectionalCollection`, `RandomAccessCollection` — a tower of
  protocols where each tier adds *algorithmic guarantees* (not just more methods).
  Generic algorithms like `reversed()`, `shuffled()`, `sorted(by:)` are written
  against the tier that genuinely needs them and specialize for every conformer.
- `Numeric`, `BinaryInteger`, `FloatingPoint`, `AdditiveArithmetic` — a protocol
  hierarchy that *replaced* C++'s class-template `numeric_traits` machinery.
- `Codable = Encodable & Decodable` — a protocol composition that subsumes the
  GoF Visitor for the serialization use case (section 4.6).

No class hierarchy would be flexible enough for this. The evidence that POP
"works" is not any particular app — it is the Swift standard library itself.

---

## 4. GoF → POP pattern transforms

This is the payoff. For each pattern, "POP form" is the Swift-native shape;
"class form" is the ceremonial OO shape you should not reach for first.

### 4.1 Template Method → protocol + extension

**Class form**: abstract superclass with a concrete `template()` method calling
abstract `step1()`, `step2()`, `step3()` hooks, each subclass overrides some
subset.

**POP form**: protocol declares the requirements; an extension supplies the
"template" function calling them. Any type — including a value type — can conform.

```swift
protocol ReportGenerator {
    func header() -> String
    func body() -> String
    func footer() -> String
}
extension ReportGenerator {
    func footer() -> String { "--- end ---" }
    func render() -> String { header() + "\n" + body() + "\n" + footer() }
}
```

The extension **is** the skeleton. Overriding `footer` in a conformer is the
only step needed. No subclass ceremony, no `abstract` keyword.

### 4.2 Strategy → closure, or generic parameter over a protocol

**Class form**: `Strategy` interface with multiple `ConcreteStrategyA`, `B`, `C`
classes; context holds a reference.

**POP form**: 90% of the time, the strategy is just a function value. When you
need associated-type relationships, constrain a generic.

```swift
// Function-value form: almost always preferred
Array.sorted(by: (Element, Element) -> Bool)

// Generic-over-protocol form: when the strategy has its own state / associated types
protocol CompressionStrategy { func compress(_ data: Data) -> Data }
struct Archive<S: CompressionStrategy> { var strategy: S; var data: Data }
```

### 4.3 Abstract Factory → protocol with associated types

**Class form**: `WidgetFactory` superclass with `createButton()`, `createCheckbox()`
abstract methods; per-platform subclasses.

**POP form**: a protocol whose associated types declare the *product family*.

```swift
protocol WidgetKit {
    associatedtype Button: ButtonProtocol
    associatedtype Checkbox: CheckboxProtocol
    func makeButton()   -> Button
    func makeCheckbox() -> Checkbox
}
struct MacWidgetKit: WidgetKit { /* returns AppKit-backed types */ }
struct WebWidgetKit: WidgetKit { /* returns HTML-backed types */ }
```

In practice, the Swift community replaces this with a **struct-of-closures**
plus `@Environment` injection (SwiftUI, Point-Free's TCA style). See
`swift-idioms.md` for that variant.

### 4.4 Bridge → one protocol + one generic

**Class form**: two parallel class hierarchies glued by composition to avoid the
N×M subclass explosion.

**POP form**: a protocol is the abstraction; a generic parameter is the
implementation slot. Composition collapses the parallel hierarchies into one.

```swift
protocol Renderer { func draw(_ shape: some Shape) }
struct ShapeView<R: Renderer> { var renderer: R; var shape: any Shape }
```

SwiftUI `View` + `ViewModifier` is the living example: `View` is the abstraction,
the concrete body is the implementation, modifiers compose without subclassing.

### 4.5 Adapter → retroactive conformance

**Class form**: an adapter class holding a reference to the adaptee and
forwarding calls.

**POP form**: extend the foreign type directly. No wrapper.

```swift
// `CLLocation` is Apple's; `Mappable` is yours.
extension CLLocation: Mappable {
    var coordinate2D: Coordinate { .init(lat: coordinate.latitude, lon: coordinate.longitude) }
}
```

`Codable` generalizes this to serialization: instead of writing a
`JSONAdapter`, you declare `: Codable` and the compiler synthesizes both sides.

### 4.6 Visitor → exhaustive `switch` on a sealed enum

The GoF Visitor's whole purpose — *"add operations without modifying the element
classes"* — was a workaround for languages that lack sum types. Swift has them.

```swift
enum Shape {
    case circle(r: Double)
    case rect(w: Double, h: Double)
    case triangle(a: Double, b: Double, c: Double)
}
extension Shape {
    var area: Double {
        switch self {
        case .circle(let r):        return .pi * r * r
        case .rect(let w, let h):   return w * h
        case .triangle(let a, let b, let c):
            let s = (a + b + c) / 2
            return (s * (s-a) * (s-b) * (s-c)).squareRoot()
        }
    }
}
```

Adding a new case forces every `switch` that claimed exhaustiveness to update.
That is the compile-time guarantee Visitor tried to simulate at runtime via
double dispatch. The one place you *will* see a Visitor-shape in Swift is
`Codable`'s `Encoder` / `Decoder`: generic over the format, the type accepts a
coder and walks its own structure. That's framework-level Visitor and it earns
its keep.

### 4.7 Decorator → protocol composition + property wrappers

**Class form**: `Decorator` abstract class implementing the same interface as
the component; chains decorators wrapping a base.

**POP form**: for views, `ViewModifier` chains (`.padding().background(.red)`).
For properties, wrappers (`@Published`, `@AppStorage`, `@FocusState`) each add
storage/observation/persistence to a plain value. For middleware, async
closures wrapping a base call.

```swift
Text("Hello")
    .padding()
    .background(.yellow)
    .clipShape(.capsule)
    .shadow(radius: 4)
```

### 4.8 Iterator → `Sequence` + `IteratorProtocol` (literal POP)

There is no more to say. The GoF pattern is a stdlib protocol pair. For async,
`AsyncSequence` + `AsyncIteratorProtocol`. You never hand-write an iterator — you
conform or use a combinator.

### 4.9 Observer → `@Observable` macro (iOS 17+), protocols for legacy code

Pre-iOS 17: `ObservableObject` + `@Published` (class-bound, Combine-backed) or
the classic delegate protocols (`UITableViewDelegate`). Post-iOS 17: the
`@Observable` macro + `@State` in SwiftUI. Observers are now invisible — views
auto-subscribe to the *properties they actually read* inside `body`. The
boilerplate is gone.

### 4.10 State → enum with associated values (preferred) or protocol dispatch

**Class form**: `State` protocol with concrete state classes, context holds
current state, transitions swap references.

**POP form**: if each state is just data, use an enum with associated values and
a reducer `switch`. Only reach for the protocol-per-state form when each state
has genuinely heavy behaviour and you need polymorphic dispatch.

```swift
enum LoadState<T> {
    case idle, loading, loaded(T), failed(Error)
}
```

### 4.11 Command → closure; occasionally a one-method protocol; `enum Action` for reducers

A closure that captures its arguments **is** a Command. The single-method
protocol form survives for cases where the command needs identity, serialization,
or undo metadata — and even there, `enum Action` with associated values plus a
reducer is the modern Swift shape.

---

## 5. The "don't overdo it" section — POP failure modes

A decade of POP in the wild has surfaced real pitfalls. None of them invalidate
the thesis; all of them are traps for developers who read the slogan and skipped
the context.

### 5.1 Protocol soup — "start with a protocol" taken literally

Napier's confession is the canonical story: *"I made a UserProtocol and a
DocumentProtocol and a ShapeProtocol and on and on, and then started implementing
all those protocols with generic subclasses."* The result: a codebase where every
concrete type has a parallel protocol with exactly one conformer, doubling the
reading surface area for zero reuse.

The corrective is Napier's: **write concrete code first, then factor**. A
protocol should exist because *two or more* concrete types need the same
treatment, or because *the caller* genuinely benefits from abstracting over the
type. Solo protocols are cargo-culted interfaces.

### 5.2 Protocols with Associated Types (PATs) friction

Alexis Gallagher's 2015 Functional Swift Conference talk
[*Protocols with Associated Types*](https://alexisgallagher.com/talks/PATs/)
identified the single biggest source of POP pain. His central objection:

> *"PATs are only usable as generic constraints — a rule that excludes PATs from
> literally every single use of 'protocols' as defined in Objective-C. Everywhere
> you wanted a protocol, you need a generic instead."*

The gap between Apple's marketing ("protocols are first-class types") and the
reality (`let c: Collection = [1,2,3]` — error: `Collection` has associated type
requirements) was the single most common beginner complaint. Gallagher's
workaround menu — *"call them PATs, embrace generics, use enums to push variation
into values, use type erasure (`AnyCollection`, `AnySequence`) for dynamic
dispatch, or wait for existentials"* — was the only honest playbook for several
years.

Type erasure (`AnySequence`, `AnyPublisher`, `AnyView`) is the specific ceremony
PATs force on you — each type-eraser is a hand-written wrapper storing closures
that forward to the underlying protocol methods. Apple's own eraser types are
how the SDK hides this pain.

### 5.3 `some` / `any` confusion and existential cost

Before Swift 5.6 / SE-0335, writing `func f(x: Sequence)` silently gave you an
existential. Most developers didn't know what that meant, and the faster form
(generics) was harder to type than the slower form (existential). SE-0335 fixed
this by requiring `any` explicitly: `any Sequence` for existentials, `some
Sequence` for opaque types. In Swift 6 the bare-protocol-as-type spelling is an
error.

The rule that actually scales:

- **Default to `some P`** for parameters and return types whose concrete type
  doesn't need to vary per call. Free specialization, no existential box.
- **Use `<T: P>` generics** when the *caller* chooses the type and you might
  need multiple type parameters that interact.
- **Use `any P`** only when you need heterogeneous storage (`[any Drawable]`) or
  when the type is selected dynamically at runtime.

### 5.4 Default-implementation dispatch surprises

A protocol extension method that is **not** a protocol requirement dispatches
statically. Conforming types can shadow it without `override` and without
warning:

```swift
protocol Greeter { func greet() }
extension Greeter {
    func shout() { print(greet().uppercased()) }   // NOT a requirement
}
struct Friend: Greeter {
    func greet() -> String { "hi" }
    func shout() { print("custom") }               // shadows, does not override
}

let g: any Greeter = Friend()
g.shout()       // prints "HI"  ← dispatches to extension (static)
Friend().shout()// prints "custom"
```

The fix: if a method should be overridable, **declare it in the protocol**, not
just in the extension. Without that, every call through an existential or
generic constraint will dispatch statically to the default.

### 5.5 Over-abstracting kills specialization

An `any Sequence` stored property is a witness-table indirection per operation.
An `[any Drawable]` array cannot be vectorized. Swift's compiler is very good at
specializing generics, but only when the concrete type is visible at the call
site. Wrapping everything in existentials "for flexibility" is exactly the
class-inheritance-style pessimization that POP was supposed to avoid.

### 5.6 Protocols as dependency-injection seams — still overused

The pattern of *"I need to mock this for tests, so I'll make a protocol"* is
correct in principle, tedious in practice. In modern Swift (especially Point-Free
/ TCA codebases), a **`struct` of closures** plus an environment is the
lighter-weight alternative — it composes, mocks, and overrides without requiring
every dependency to carry a protocol definition alongside its implementation.

---

## 6. When to still use a class in 2025 Swift

Abrahams' own list updated for the modern language:

1. **Reference identity genuinely matters.** A `URLSession`, a `CBPeripheral`, an
   `NSManagedObject`. Two instances are *not* interchangeable because they point
   at the same external resource.
2. **Shared mutable state, with known access discipline.** A cache, a pool, a
   connection — things that must be observed or mutated from multiple places
   without copying. Pair with `@MainActor` or a custom global actor.
3. **Obj-C / framework interop.** `NSObject` subclasses, `UIViewController`,
   `NSDocument`, `AppDelegate`. Don't fight AppKit or UIKit — the framework is
   classes all the way down.
4. **`deinit` matters.** File handles, sockets, Metal resources, C handles
   owning heap memory. Structs have no deinit.
5. **Existential erasure is cheaper than generic explosion.** Rare, but real:
   when specializing per conformer would balloon binary size and you know the
   hot path tolerates dynamic dispatch, `class` or `any P` boxed in a class is
   the escape hatch.
6. **SwiftUI's own seams require it.** `@StateObject`, `ObservableObject`,
   `@Observable` all require class-bound model types — SwiftUI caches by
   reference identity across view redraws. `struct` can't do that.
7. **Copy-on-write wrapping a big storage buffer.** The `isKnownUniquelyReferenced`
   idiom: a public struct wraps a private class reference, checks uniqueness
   before mutation, and clones only when needed. `Array`, `String`, `Dictionary`
   do this internally; the [Swift-CowBox macro](https://github.com/Swift-CowBox/Swift-CowBox)
   generates it for your own types.

Mark every class `final` unless you have a specific subclassing story. Swift's
class model still suffers from the fragile base class problem Crusty warned
about, and `final` lets the compiler devirtualize calls.

---

## 7. Modern retrospective — what the POP decade actually taught us

A decade on, the community has settled on a more nuanced reading than the 2015
"classes are bad" slogan:

- **POP won on capabilities, not on identities.** The wins are `Equatable`,
  `Hashable`, `Codable`, `Sendable`, `Sequence`, `Collection`, `Identifiable` —
  protocols that describe what a type *can do*. POP lost on trying to replace
  identity-bearing OO hierarchies with PAT towers; SwiftUI went back to classes
  for model objects specifically because identity matters.
- **`@Observable` + `@MainActor` reintroduced classes as model objects.** Apple's
  own 2023–2025 direction (`@Observable`, `@Model`, SwiftData) uses classes
  precisely where the 2015 talk said not to, because SwiftUI's invalidation
  algorithm depends on reference identity. The lesson: POP is a tool for
  capabilities and algorithms; classes are a tool for identity and lifetime.
- **Primary associated types (Swift 5.7, SE-0346) finally made PATs usable as
  existentials.** You can now write `any Collection<Int>`, `any Publisher<Value,
  Never>`, `some Sequence<String>`. Gallagher's entire critique is, in 2025,
  mostly resolved at the surface syntax level — though the underlying
  existential cost remains.
- **`some` by default, `any` on demand.** The WWDC 2022 *Embrace Swift generics*
  guidance (which builds on SE-0335) is the clearest articulation of how to use
  POP without paying for it: opaque return types for everything that can be
  specialized, existentials only when storage flexibility demands it.
- **Value types + actors beat classes + locks.** The original Crusty complaint
  about race conditions is now addressed at the language level — `struct`s give
  you no shared mutable state, `actor`s and `@MainActor` give you serialized
  access when you do need shared state, and `Sendable` is a compile-time check.
  This is POP's deepest win, and it's the part of the 2015 vision that aged
  best.
- **"Start with a protocol" is wrong in isolation.** Napier was right. The
  useful version is *"start with concrete types, extract a protocol when two or
  more concrete types need the same treatment, or when the caller benefits from
  abstracting over them."*

The one-line summary: **Crusty was mostly right about classes, and the Swift
community spent a decade working out which 80% of his argument survived contact
with real UI frameworks.**

---

## 8. Sources

- Apple — [Protocol-Oriented Programming in Swift (WWDC 2015 Session 408)](https://developer.apple.com/videos/play/wwdc2015/408/) · [ASCIIwwdc transcript mirror](https://asciiwwdc.com/2015/sessions/408) · [WWDC Index](https://nonstrict.eu/wwdcindex/wwdc2015/408/)
- Apple — [Embrace Swift generics (WWDC 2022)](https://developer.apple.com/videos/play/wwdc2022/110352/) · [Design protocol interfaces in Swift (WWDC 2022)](https://developer.apple.com/videos/play/wwdc2022/110353/) · [Observation framework docs](https://developer.apple.com/documentation/Observation)
- Rob Napier — [*Start With a Protocol*](https://robnapier.net/start-with-a-protocol) — retrospective critique of the slogan, ten years in
- Alexis Gallagher — [*Protocols with Associated Types, and How They Got That Way*](https://alexisgallagher.com/talks/PATs/) (Functional Swift 2015) · [YouTube](https://www.youtube.com/watch?v=XWoNjiSPqI8)
- WWDC 2015 notes — [rbobbins' community notes](https://gist.github.com/rbobbins/de5c75cf709f0109ee95) · [InfoQ writeup](https://www.infoq.com/news/2015/06/protocol-oriented-swift/)
- Swift Evolution — [SE-0335 Introduce existential `any`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md) · [SE-0346 Lightweight same-type requirements for primary associated types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0346-light-weight-same-type-syntax.md) · [SE-0358 Primary Associated Types in the Standard Library](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0358-primary-associated-types-in-stdlib.md) · [SE-0244 Opaque Result Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0244-opaque-result-types.md) · [SE-0393 Value and Type Parameter Packs](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0393-parameter-packs.md)
- Paul Hudson — [Introduce existential any](https://www.hackingwithswift.com/swift/5.6/existential-any) · [Lightweight same-type requirements](https://www.hackingwithswift.com/swift/5.7/primary-associated-types)
- John Sundell — [Referencing generic protocols with `some` and `any`](https://www.swiftbysundell.com/articles/referencing-generic-protocols-with-some-and-any-keywords/)
- Donny Wals — [What is the `any` keyword in Swift?](https://www.donnywals.com/what-is-the-any-keyword-in-swift/) · [Differences between `any` and `some`](https://www.donnywals.com/whats-the-difference-between-any-and-some-in-swift-5-7/)
- Antoine van der Leest (SwiftLee) — [Existential `any` in Swift](https://www.avanderlee.com/swift/existential-any/) · [Protocol-Oriented Programming](https://www.avanderlee.com/swift/protocol-oriented-programming/)
- Matt Massicotte — [Singletons with Swift Concurrency](https://www.massicotte.org/singletons/) — why `@MainActor final class` + `static let shared` replaces most class singletons
- objc.io — [Protocols & Class Hierarchies (S01E29)](https://talk.objc.io/episodes/S01E29-protocols-class-hierarchies)
- [Swift-CowBox macro](https://github.com/Swift-CowBox/Swift-CowBox) — copy-on-write for custom structs
