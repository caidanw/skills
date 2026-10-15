# Singleton

**Category:** Creational · **Modern relevance:** Mostly anti-pattern. Use DI or module-level values.

## Intent

Ensure a class has **exactly one instance** and provide a global access point to it.

## Problem

Shared resources — a database pool, a logger, a config registry — need coordination. Multiple
independent instances would waste resources or create inconsistency. A raw global variable is worse:
anyone can reassign it.

## Structure

- Private constructor.
- Private static field holding *the* instance.
- Public static `getInstance()` that lazily initializes and returns it.
- In multithreaded code: double-checked locking, eager init, or language primitives (`static` in
  C++11+, `object` in Kotlin, module-level in Python).

## Applicability (the legitimate cases)

- A single hardware/OS resource (printer spooler, audio output).
- Process-wide config loaded once at startup.
- Logger facade.
- Caches that must be global to function.

## Consequences

**Pros:** One instance guaranteed. Global access. Lazy init.

**Cons — this is the pattern where the cons win:**
- **Global mutable state** — the thing every clean-code book tells you to avoid.
- **Violates SRP** — conflates "what the class does" with "how many there are."
- **Murders testability** — can't swap per test; tests leak state between each other.
- **Hides dependencies** — a class that secretly calls `Logger.getInstance()` lies about what it needs.
- **Threading hazards** — memory-model expertise most developers lack.
- **Subclassing and serialization break** in subtle ways.

## When NOT to use (almost always)

- "Accessible everywhere" — that's a DI problem, not a lifecycle problem.
- Logger or config — inject them. Testability alone pays for the longer constructor.
- Mutable state touched by multiple threads — you almost certainly have a race condition.
- More than one Singleton in your codebase — you've rebuilt a service locator without admitting it.

## Modern relevance

**Mostly anti-pattern.** It survived because it was in the book, not because it was good. Modern
replacements:

- **Dependency injection** — register as singleton in a DI container (Spring's default scope,
  NestJS providers, FastAPI's `Depends` with caching). Same uniqueness, fully testable.
- **Module-level values** — Python `config = load_config()` at module top. ES modules. Same thing,
  zero class ceremony, tests can mock the module.
- **Closures** — factory function returning a memoized instance.

Legitimate uses still exist (hardware-bound resources, framework internals). If you're writing
`getInstance()` in 2026, stop and justify it.

## Code sketch (TypeScript — reference form, not endorsed)

```ts
class Logger {
  private static instance: Logger | null = null
  private constructor(private prefix: string) {}

  static getInstance(): Logger {
    if (!Logger.instance) Logger.instance = new Logger("[app]")
    return Logger.instance
  }

  log(msg: string) { console.log(`${this.prefix} ${msg}`) }
}

Logger.getInstance().log("hello")
```

## Code sketch (modern replacement)

```ts
// logger.ts — every import gets the same instance. Testable via module mocking / DI.
export const logger = { log: (m: string) => console.log(`[app] ${m}`) }
```

## Real-world uses

- `java.lang.Runtime.getRuntime()`
- Python `logging.getLogger(name)` (flyweight-ish, but singleton per name)
- Spring `@Scope("singleton")` (default) — DI-managed singletons, the *good* kind
- Node.js module caching — every `require`'d module is effectively a singleton
- Redux store (one per app, typically)

## Distinguishing from neighbors

- **vs. Flyweight** — Singleton is one instance, often mutable, for identity reasons. Flyweight is
  *many* shared immutable instances for memory reasons.
- **vs. Monostate** — Singleton has one instance with many refs; Monostate has many instances
  sharing static fields. Both are usually wrong.

## Rule of thumb

If you find yourself typing `getInstance`, ask: can this be a module-level value? Can it be a
DI-registered service? If yes (it almost always is), do that instead. Singleton is the canonical
case where *naming the pattern* is useful and *implementing the pattern* usually isn't.
