---
name: design-patterns-gof
description: >-
  The 23 Gang of Four object-oriented design patterns (Gamma, Helm, Johnson, Vlissides, 1994)
  distilled as a practical field guide, not a catalog. Use when naming a shape in code review,
  choosing between competing designs, deciding whether to introduce indirection, or auditing for
  over-abstraction. Each pattern documents intent, tradeoffs, modern relevance, language-level
  replacements, and when NOT to use it. Triggers on: "design pattern", "GoF", "factory", "builder",
  "singleton", "adapter", "decorator", "observer", "strategy", "visitor", "state machine",
  "command pattern", "too many constructors", "subclass explosion", "program to an interface",
  "composition over inheritance", "am I over-abstracting this".
---

# Design Patterns (Gang of Four)

Field guide to the 23 patterns from *Design Patterns: Elements of Reusable Object-Oriented
Software* (Gamma, Helm, Johnson, Vlissides, 1994), updated for modern TypeScript/Python/Rust/Swift
practice. Each pattern lives in its own reference file — this SKILL.md is the index and the
meta-level (principles, categories, decision tree, criticism).

## Why use this skill

- You want the **vocabulary** — naming a shape ("this is a Decorator chain") beats a paragraph of prose in PR review.
- You're about to introduce an abstraction and want to sanity-check whether it earns its keep.
- You're reading a codebase that leans on patterns and need a map.
- You're translating a C++/Java pattern into a language with first-class functions and sum types.

This skill is **opinionated**. In 2026, a lot of GoF ceremony dissolves into language features
(closures, discriminated unions, generators, pattern matching, DI containers). The patterns that
survived kept their names because the *shape* is useful; the *class hierarchies* often aren't.

## The two core principles (the spine of the book)

Every pattern in the book is a recipe for one or both of these:

1. **Program to an interface, not an implementation.** Depend on the abstract contract, not the
   concrete class. You can swap implementations, test with fakes, and change internals without
   touching callers.
2. **Favor object composition over class inheritance.** Inheritance is white-box reuse — the
   subclass sees the parent's internals and is tightly coupled. Composition is black-box reuse —
   you hold a reference and call its interface. Most behavioral patterns exist to express
   composition in a language that defaulted to inheritance.

When a pattern feels wrong, it's usually because one of these principles was violated (e.g.,
Template Method forces inheritance; Singleton exposes global state and hides dependencies).

## The four elements of a pattern (GoF Ch. 1)

Every pattern documented here has:

1. **Name** — handle for design conversation. The vocabulary is the real product.
2. **Problem** — the context and preconditions that make the pattern applicable.
3. **Solution** — the participants, relationships, and collaborations. A template, not code.
4. **Consequences** — tradeoffs. **Most important and most often stripped** from tutorials.
   A pattern without stated consequences is a cargo cult.

## The 23 patterns at a glance

### Creational (5) — *object construction*

| Pattern | One-line intent | Modern relevance |
|---|---|---|
| [Abstract Factory](references/creational/abstract-factory.md) | Produce families of related objects through one interface | Low-mid. DI containers subsume most uses. |
| [Builder](references/creational/builder.md) | Construct complex objects step-by-step; avoid telescoping constructors | High (fluent APIs everywhere). Rust-canonical. |
| [Factory Method](references/creational/factory-method.md) | Subclass (or function) decides which concrete class to instantiate | High. `Array.of`, `Promise.resolve`, `URL.createObjectURL`. |
| [Prototype](references/creational/prototype.md) | Clone an existing instance instead of constructing from scratch | Low in app code; high in game engines / scene graphs. |
| [Singleton](references/creational/singleton.md) | One instance, global access | **Mostly anti-pattern.** Use DI or module-level values. |

### Structural (7) — *object composition*

| Pattern | One-line intent | Modern relevance |
|---|---|---|
| [Adapter](references/structural/adapter.md) | Translate one interface to another so incompatible objects can collaborate | Ubiquitous at system boundaries. |
| [Bridge](references/structural/bridge.md) | Split abstraction and implementation into two hierarchies linked by composition | Moderate. JDBC, React renderers. |
| [Composite](references/structural/composite.md) | Treat individual objects and groups uniformly via a tree | Ubiquitous. DOM, ASTs, scene graphs. |
| [Decorator](references/structural/decorator.md) | Stack behaviors onto an object at runtime | Ubiquitous (middleware under different names). |
| [Facade](references/structural/facade.md) | One narrow API over a complex subsystem | Very high. SDK clients, service classes. |
| [Flyweight](references/structural/flyweight.md) | Share fine-grained objects to save memory | Niche. Graphics, text rendering, ECS. |
| [Proxy](references/structural/proxy.md) | Surrogate that controls access to another object | Enormous. ORMs, gRPC stubs, Vue/MobX reactivity. |

### Behavioral (11) — *communication and responsibility*

| Pattern | One-line intent | Modern relevance |
|---|---|---|
| [Chain of Responsibility](references/behavioral/chain-of-responsibility.md) | Pass a request through a chain of handlers | Ubiquitous as middleware. |
| [Command](references/behavioral/command.md) | Encapsulate a request as a first-class object | High (CQRS, Redux actions, job queues). |
| [Interpreter](references/behavioral/interpreter.md) | Represent a grammar and evaluate sentences in it | Low. Use parser combinators / ADTs. |
| [Iterator](references/behavioral/iterator.md) | Traverse a collection without exposing its structure | Built into every modern language. |
| [Mediator](references/behavioral/mediator.md) | Central hub coordinates peers so they don't talk directly | Moderate. Redux/Zustand stores, chat servers. |
| [Memento](references/behavioral/memento.md) | Capture and restore an object's state without breaking encapsulation | High (undo, time travel, transactions). |
| [Observer](references/behavioral/observer.md) | Publisher notifies many subscribers of state changes | Ubiquitous (EventEmitter, RxJS, signals). |
| [State](references/behavioral/state.md) | Object's behavior changes with internal state via delegation | High. XState, typestate, UI state machines. |
| [Strategy](references/behavioral/strategy.md) | Interchangeable algorithms behind one interface | Ubiquitous — usually just a function. |
| [Template Method](references/behavioral/template-method.md) | Fixed algorithm skeleton; subclasses override steps | Mostly framework internals. Prefer Strategy. |
| [Visitor](references/behavioral/visitor.md) | Add operations to an object structure without modifying it | Niche (compilers). Prefer pattern matching. |

## Decision tree — which category to look in

```
Is the pain about...
  ├─ CONSTRUCTION?        → Creational
  │    • Too many constructor args / optional config?    → Builder
  │    • Need to swap families together?                 → Abstract Factory
  │    • Subclass decides concrete type?                 → Factory Method
  │    • Construction expensive / copy cheaper?          → Prototype
  │    • (Singleton: almost never — use DI.)
  │
  ├─ SHAPE / WIRING?      → Structural
  │    • Incompatible interfaces?                        → Adapter
  │    • Add responsibility without subclassing?         → Decorator
  │    • Tree / part-whole with uniform treatment?       → Composite
  │    • Simplify access to subsystem?                   → Facade
  │    • Control access / lazy / remote?                 → Proxy
  │    • Decouple two hierarchies (what vs. how)?        → Bridge
  │    • Share millions of fine-grained objects?         → Flyweight
  │
  └─ BEHAVIOR / COMMS?    → Behavioral
       • Swap algorithm at runtime?                      → Strategy (usually just a function)
       • Broadcast to many listeners?                    → Observer
       • Encapsulate request (queue / undo / log)?       → Command (+ Memento for undo)
       • Step through a collection uniformly?            → Iterator (usually built-in)
       • Walk a heterogeneous tree?                      → Visitor (prefer pattern matching)
       • Object acts differently per internal mode?      → State
       • Skeleton with customizable steps?               → Template Method (prefer Strategy)
       • Many-to-many chatter → one hub?                 → Mediator
       • Try handlers until one succeeds?                → Chain of Responsibility
       • Capture/restore state?                          → Memento
       • Evaluate a domain grammar?                      → Interpreter (prefer parser combinators)
```

Before committing to any leaf, run **two checks**:

1. **Does my language already have this?** Strategy = function. Iterator = `for`/generator.
   Command = closure + data. Observer = pub/sub primitive. Visitor = `match` on union. If the
   language answers, stop.
2. **Have I seen this shape three times?** (Rule of Three, Fowler.) If not, inline it. Two
   occurrences aren't enough signal — the "common" shape is usually an illusion, and the wrong
   abstraction is more expensive than duplication (Sandi Metz).

## How patterns combine (the real value)

Real systems stack 3–5 patterns. Key relationships from GoF's inter-pattern graph:

- **Abstract Factory** is often built with **Factory Methods** or **Prototypes**.
- **Composite** is almost always traversed with **Iterator** or **Visitor**.
- **Decorator** and **Composite** share recursive structure; differ in intent (augment vs. aggregate).
- **Command + Memento** = undo stack.
- **Chain of Responsibility** is often built on **Composite** (the tree is the chain).
- **Mediator** often uses **Observer** internally.
- **State** and **Strategy** share a class diagram; differ in who drives transitions.
- **Visitor** + **Composite** + **Iterator** is the compiler-writer's trio.
- **Interpreter**'s AST is a **Composite**.

## When to reach for a pattern — and when you're over-abstracting

**Signs you're over-abstracting:**
- One concrete implementation behind a factory/interface. Delete the indirection.
- Class names like `AbstractSingletonProxyFactoryBean` — the pattern chain is the identity.
- "We'll need it later." You won't. YAGNI.
- The pattern appears before the duplication (UML before the second caller).
- Anemic domain: all behavior lives in services, entities are getter-bags. No pattern fixes a modeling problem.

**Signs you actually need it:**
- A shape has repeated three times with real variation.
- Multiple *actual* implementations exist today (payment providers, renderers, formats).
- You want a specific **consequence** (undo, part-whole uniformity, runtime algorithm swap).
- The team needs a shared name to stop re-deriving the design in every review.

## Criticism and modernity — essential context

Three long-running critiques have become conventional wisdom; treat them as load-bearing:

1. **Patterns as workarounds for weak languages** (Paul Graham, "Revenge of the Nerds"). If you're
   hand-expanding a template, your language is missing a construct.
2. **Patterns dissolve in expressive languages** (Peter Norvig, 1996). 16 of 23 GoF patterns are
   invisible or trivial in Lisp/Dylan. In 2026 most of those language features exist in
   TS/Python/Rust/Swift/Kotlin — so the *class hierarchies* dissolve while the *shape names* stay
   useful.
3. **Cargo cult risk** (Jeff Atwood). Patterns as templates-to-apply rather than tools-for-problems
   produce classes whose names leak implementation rather than naming domain concepts.

Full treatment in [references/criticism-and-modernity.md](references/criticism-and-modernity.md).

## What's still canonical vs. what aged poorly

**Still alive under their GoF names:** Adapter, Facade, Proxy, Decorator, Observer, Composite,
Iterator (as protocol), Strategy (as function), Builder, Factory Method, State, Command, Chain of
Responsibility, Memento.

**Mostly anti-patterns or heavily displaced:**
- **Singleton** — global state, test-hostile. Replaced by DI or module-level values.
- **Visitor** — replaced by pattern matching on sealed hierarchies / discriminated unions.
- **Template Method** — violates composition-over-inheritance. Prefer Strategy.
- **Abstract Factory** — absorbed by DI containers.
- **Interpreter** — parser combinators and ADT + recursive `eval` are better.
- **Prototype** — niche outside game engines; immutable data makes it redundant.

## How to use this skill

1. Identify the axis of pain (construction / structure / behavior) using the decision tree.
2. Read the candidate pattern's reference file. Look at **Modern Relevance** and **When NOT to Use**
   *before* you look at the structure — those sections tell you whether to even continue.
3. If you adopt the pattern, prefer the language-native form (function, union, closure) to the
   class-heavy GoF form unless you actually need the ceremony (serialization, persistence, cross-
   language interop, explicit dispatch).
4. Name it in code and PRs. The vocabulary is half the point.
