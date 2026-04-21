# Observer

**Category:** Behavioral · **Modern relevance:** Ubiquitous (EventEmitter, RxJS, signals)

## Intent

Define a one-to-many subscription mechanism so that when one object changes state, all its
dependents are notified automatically.

## Problem

State change in A must propagate to N unknown-at-compile-time objects (UI components, caches,
loggers). Polling wastes cycles; hard-coded callbacks couple A to every observer.

## Structure

- **Subject/Publisher** maintains a list of subscribers; exposes `subscribe`/`unsubscribe`/`notify`.
- **Observer/Subscriber** interface declares `update(event)`.
- **Concrete Observers** implement reactions.
- **Client** wires subscribers to publishers.

## Applicability

- UI that updates when model state changes (MVC/MVVM).
- Event buses and pub/sub across decoupled modules.
- Reactive data flows (stock prices, telemetry, websockets).
- Cache invalidation, audit logging, analytics fan-out.

## Consequences

**Pros:** Open/closed for new subscribers. Dynamic runtime subscription. Loose coupling.

**Cons:** Notification order is undefined. Easy memory leaks from missing unsubscribe. Synchronous
cascades hard to reason about. Infinite loops if an observer's reaction mutates the subject.

## When NOT to use

- Single, known consumer — call it directly.
- Complex multi-step orchestrations — an event bus obscures control flow; a state machine or
  explicit pipeline is clearer.

## Modern relevance

One of the most alive GoF patterns, under many names. Node `EventEmitter`, DOM `addEventListener`,
RxJS `Observable`/`Subject`, React `useSyncExternalStore`, Svelte stores, Vue refs/computed, signals
(Solid/Preact/Angular), MobX reactions, Kafka consumers, WebSockets, SwiftUI `@Published` +
`ObservableObject`, Combine publishers. If you've written `on("change", fn)` you've used Observer.

## Code sketch (TypeScript)

```ts
type Listener<T> = (value: T) => void

class Signal<T> {
  private listeners = new Set<Listener<T>>()
  constructor(private value: T) {}
  get() { return this.value }
  set(v: T) { this.value = v; this.listeners.forEach(l => l(v)) }
  subscribe(fn: Listener<T>) {
    this.listeners.add(fn)
    return () => this.listeners.delete(fn)   // unsubscribe
  }
}

const count = new Signal(0)
const off = count.subscribe(v => console.log("count:", v))
count.set(1)
count.set(2)
off()
```

## Real-world uses

- Redux subscribers, RxJS/Observable streams
- React re-renders via signals/stores
- DOM events, Node `EventEmitter`
- Kafka/NATS pub/sub
- SwiftUI/Combine
- MobX observables
- Spreadsheets (cell dependencies)

## Distinguishing from neighbors

- **vs. Mediator** — Observer is direct publisher-subscriber (publisher owns the list). Mediator is
  a central coordinator that both sides notify. Mediators often use Observer under the hood.
- **vs. Chain of Responsibility** — Observer broadcasts to many; CoR passes sequentially.
- **vs. Command** — Command is the *message* sent; Observer is the *delivery mechanism*. They pair.

## Functional equivalent

Array (or Set) of callbacks + `notify()` function. Signals, RxJS Observables, Solid-style
reactivity are Observer with ergonomic sugar.

## Rule of thumb

Always remember to return the unsubscribe function from `subscribe`. The #1 source of memory leaks
in Observer-heavy code is orphaned listeners. Prefer signals / reactive primitives over raw
EventEmitter when available — they handle lifecycle better.
