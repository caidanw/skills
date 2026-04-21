# Factory Method

**Category:** Creational · **Modern relevance:** High (as static factory functions)

## Intent

Define an interface for creating an object, but let **subclasses (or a callback) decide which class
to instantiate**. Defer instantiation to a single override point.

## Problem

A `LogisticsApp` was coded around `Truck`. Now it needs `Ship`. Scattering
`if (transportMode === "sea")` through the codebase is a bug farm. Keep the high-level workflow
(`planDelivery()`) generic and push the "which transport?" question to one override point.

## Structure

- **Product** — common interface (`Transport.deliver()`).
- **Concrete Products** — `Truck`, `Ship`.
- **Creator** — declares factory method (`createTransport(): Transport`) and contains the business
  logic that *uses* the product.
- **Concrete Creators** — `RoadLogistics`, `SeaLogistics` override it.

## Applicability

- Framework extension points (users subclass a base and override creation).
- Exact class depends on runtime configuration or input.
- Object pooling — the factory method hides whether you got a fresh or recycled instance.
- Non-trivial construction logic (validation, caching, registration side effects).

## Consequences

**Pros:** Decouples creator from concrete products. Single Responsibility. Open/Closed (new
products via new subclasses).

**Cons:** Parallel subclass hierarchy just to vary creation — heavy in languages without first-class
functions. Can be overkill when a function parameter would do.

## When NOT to use

- You're subclassing *only* to override the factory method. With first-class functions, pass
  `createTransport: () => Transport` instead.
- A single `switch` on a discriminated union is clearer for your domain.
- You're using "Factory" in the name of a static method that just calls `new` — that's a **static
  creation method**, a valid but different idiom.

## Modern relevance

The name persists even when the formal structure doesn't. `Array.of`, `Array.from`,
`Promise.resolve`, `Buffer.from`, `URL.createObjectURL`, `React.createElement` — all "factory
methods" in spirit. The inheritance-based GoF form is rarer; the **static factory function** variant
is ubiquitous and recommended by *Effective Java* Item 1.

## Code sketch (TypeScript — inheritance form)

```ts
interface Transport { deliver(cargo: string): void }

abstract class Logistics {
  protected abstract createTransport(): Transport  // factory method

  planDelivery(cargo: string) {
    const t = this.createTransport()
    t.deliver(cargo)
  }
}

class RoadLogistics extends Logistics {
  protected createTransport(): Transport {
    return { deliver: c => console.log(`Truck delivers ${c}`) }
  }
}
class SeaLogistics extends Logistics {
  protected createTransport(): Transport {
    return { deliver: c => console.log(`Ship delivers ${c}`) }
  }
}

new SeaLogistics().planDelivery("500 crates")
```

## Code sketch (TypeScript — static factory, more common today)

```ts
class User {
  private constructor(public name: string, public role: "admin" | "member") {}

  static admin(name: string)  { return new User(name, "admin") }
  static member(name: string) { return new User(name, "member") }
}

User.admin("ada")
```

## Real-world uses

- `Array.from`, `Array.of`, `Promise.resolve/reject`
- `Integer.valueOf` (caches small integers — factory methods enable pooling)
- `LocalDate.of(...)` and the whole `java.time` API
- React `createElement`, `createContext`, `forwardRef`
- Django `Model.objects.create()`

## Distinguishing from neighbors

- **vs. Abstract Factory** — Factory Method is *one* create-operation; Abstract Factory is a set
  that must agree on a family.
- **vs. Builder** — Builder exposes intermediate steps; Factory Method returns a finished product.
- **vs. Prototype** — Prototype clones an existing instance; Factory Method constructs a new one.

## Rule of thumb

Use the static factory variant freely — it's clearer than constructors for names semantics,
caching, or multi-step init. Use the inheritance-based GoF variant only for real framework
extension points. Otherwise, prefer a function parameter.
