# Criticism & Modern Relevance

Load-bearing context for why the GoF book reads differently in 2026 than it did in 1994. Three
critiques have become conventional wisdom. Understand them before reaching for any pattern.

## 1. Patterns are workarounds for weak languages — Paul Graham

> "When I see patterns in my programs, I consider it a sign of trouble. The shape of a program
> should reflect only the problem it needs to solve. Any other regularity in the code is a sign, to
> me at least, that I'm using abstractions that aren't powerful enough."
> — *Revenge of the Nerds*

If you're hand-expanding a template, your language is missing a construct (macros, higher-order
functions, sum types, etc.). The "pattern" is the symptom. In a richer language, the pattern's
existence vanishes.

## 2. Patterns dissolve in expressive languages — Peter Norvig (1996)

Norvig's talk "Design Patterns in Dynamic Programming" showed **16 of 23 GoF patterns are
invisible or simpler** in Lisp/Dylan:

| Language feature | Patterns absorbed |
|---|---|
| First-class types | Abstract Factory, Flyweight, Factory Method, State, Proxy, Chain of Responsibility |
| First-class functions | Command, Strategy, Template Method, Visitor |
| Macros | Interpreter, Iterator |
| Method combination | Mediator, Observer |
| Multimethods | Builder |
| Modules | Facade |

In 2026, most of those features are present in Python, Ruby, JS/TS, Kotlin, Swift, Rust, and Scala.
A Strategy in TypeScript is a function parameter; a Command is a closure; an Iterator is a
generator; a Visitor collapses into pattern matching over a sum type. Even the GoF authors conceded
later: their patterns assume Smalltalk/C++-level language features.

## 3. Patterns become cargo cult — Jeff Atwood

> Programmers become "fancy macro processors" — template-application over problem-solving.

The rhetorical anti-exemplar: Spring's **`AbstractSingletonProxyFactoryBean`**. A real class whose
name stacks five pattern nouns. Each layer earns its keep *internally*; the problem is the name
*leaks the how* rather than naming the domain concept. Both defenders and critics are right. The
class works; the name is the symptom.

## What aged well vs. what aged poorly

### Still canonical under their GoF names

- **Adapter** — boundaries with foreign code.
- **Facade** — simplified API over a subsystem.
- **Proxy** — access control, lazy loading, remote stubs.
- **Decorator** — middleware (implemented as a list, usually).
- **Observer** — event emitters, signals, reactive streams.
- **Composite** — trees are still trees.
- **Iterator** — now a language protocol, but the name is still used.
- **Strategy** — now usually "pass a function," but the name is ubiquitous.
- **Builder** — fluent APIs and options objects.
- **Factory Method** — static factory functions are everywhere.
- **State** — explicit state machines (XState, typestate) are thriving.
- **Command** — CQRS, event sourcing, job queues, Redux actions.
- **Chain of Responsibility** — middleware arrays.
- **Memento** — immutable snapshots, undo stacks, time-travel debugging.

### Aged poorly / mostly anti-patterns

- **Singleton** — global mutable state. Replaced by DI or module-level values. If you write
  `getInstance()` in 2026, stop and justify it.
- **Visitor** — replaced by pattern matching on discriminated unions / sealed hierarchies.
- **Template Method** — violates composition-over-inheritance (GoF's own principle!). Prefer
  Strategy.
- **Abstract Factory** — absorbed by DI containers.
- **Interpreter** — parser combinators + ADT + recursive `eval` are better.
- **Prototype** — niche outside game engines; immutable data makes it redundant for most use cases.

## The meta-takeaway

Patterns are **vocabulary**. Saying "that's a Decorator chain" in a PR comment is faster than a
paragraph of diff explanation, and 50 years of software engineers have agreed on what that means.

Patterns are **not** blueprints. Copying UML from the book into TypeScript produces
`AbstractSingletonProxyFactoryBean`. Know the shape, recognize it in the wild, but implement it in
the most idiomatic form your language affords — which is usually much thinner than the GoF
diagram.

Two principles from the book's Chapter 1 aged better than any individual pattern:

1. **Program to an interface, not an implementation.**
2. **Favor object composition over class inheritance.**

When a pattern feels wrong, it's usually violating one of these.

## Sources

- [Peter Norvig — Design Patterns in Dynamic Programming (1996)](https://norvig.com/design-patterns/)
- [Paul Graham — Revenge of the Nerds](https://www.paulgraham.com/icad.html)
- [Jeff Atwood — Rethinking Design Patterns](https://blog.codinghorror.com/rethinking-design-patterns/)
- [Refactoring.guru — Criticism of design patterns](https://refactoring.guru/design-patterns/criticism)
- [Erich Gamma interview — Design Principles from Design Patterns (Artima, 2004)](https://www.artima.com/articles/design-principles-from-design-patterns)
