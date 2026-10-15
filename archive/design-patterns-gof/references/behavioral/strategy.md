# Strategy

**Category:** Behavioral · **Modern relevance:** Ubiquitous — usually just a function

## Intent

Define a family of interchangeable algorithms, encapsulate each, and make them swappable at runtime.

## Problem

One class mushrooms with variants of the same operation (sort by X vs Y vs Z; route by car vs bike
vs transit). Every new variant balloons the class and conditionals.

## Structure

- **Strategy** interface with one method (`execute()`).
- **Concrete Strategies** implement variants.
- **Context** holds a strategy and delegates to it.
- **Client** chooses the strategy.

## Applicability

- Multiple ways to compute the same thing (sorting, pricing, routing, compression).
- Need to change algorithm at runtime or per-request.
- Isolate algorithm-specific data and logic from the main class.
- Replace large conditionals selecting between algorithm variants.

## Consequences

**Pros:** Open/closed. Composition over inheritance. Runtime switching. Better testability.

**Cons:** More moving parts. Client must know the strategies to pick one. Overkill for two stable
options.

## When NOT to use

- Two options that rarely change — `if/else` is clearer.
- You're inventing a `FooStrategy` interface to host a single method used in one place — you've
  reinvented a function.

## Modern relevance

Essentially subsumed by first-class functions. Passing a comparator to `Array.sort(fn)`, a key to
`sorted(data, key=...)`, middleware to `app.use(fn)`, a validator to Zod — all Strategy. OO
ceremony is overkill in TS/Python/Swift/Kotlin/Rust; a function parameter is idiomatic. Retain the
class form when the strategy has its own dependencies, config, or lifecycle.

## Code sketch (TypeScript — function form)

```ts
type PriceStrategy = (subtotal: number, userTier: "free" | "pro") => number

const noDiscount: PriceStrategy = s => s
const proTenPct:  PriceStrategy = (s, t) => t === "pro" ? s * 0.9 : s
const flashSale:  PriceStrategy = s => s * 0.75

class Cart {
  constructor(private price: PriceStrategy) {}
  total(sub: number, tier: "free" | "pro") { return this.price(sub, tier) }
}

new Cart(proTenPct).total(100, "pro")   // 90
new Cart(flashSale).total(100, "free")  // 75
```

## Real-world uses

- Sort comparators (`Array.sort`, `sorted(key=...)`)
- Zod validators
- Compression codec selection
- Retry/backoff policies
- Stripe payment methods
- Auth schemes (OAuth, basic, API key)
- React form validators
- Cache eviction policies (LRU/LFU/FIFO)
- Routing algorithms in maps

## Distinguishing from neighbors

- **vs. State** — Strategy is *externally selected*; State is *internally driven* by transitions.
- **vs. Command** — Command binds target + parameters; focuses on *invoking* (often once, possibly
  undoable). Strategy swaps *how* a thing is done; reused many times.
- **vs. Template Method** — Template Method uses inheritance (fixed skeleton, subclass fills steps).
  Strategy uses composition (whole algorithm swappable). **Prefer Strategy.**

## Functional equivalent

A function parameter. In 90% of modern cases, "the Strategy pattern" is "pass a function."

## Rule of thumb

If the strategy has one method and no state, pass a function. If it has multiple methods or
injected dependencies, use a class/interface. Either way, the *shape* — context-takes-strategy — is
correct; the ceremony is negotiable.
