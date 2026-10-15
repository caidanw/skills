# Mediator

**Category:** Behavioral · **Modern relevance:** Moderate (Redux-style stores, orchestration layers)

## Intent

Centralize complex communications and control between related objects so they don't reference each
other directly.

## Problem

N objects that each need to react to others produce an O(N²) mesh of direct references. A form's
checkbox enables a text field which reveals a button which toggles a label. Everything knows about
everything and nothing is reusable.

## Structure

- **Mediator** interface with `notify(sender, event)`.
- **Concrete Mediator** encapsulates coordination logic and holds references to components.
- **Components** know only the mediator; emit notifications and react to calls from it.

## Applicability

- Complex dialog boxes and forms (canonical example).
- Air-traffic-control-style coordination where peers shouldn't talk directly.
- Chat rooms (central server mediates between users).
- Decoupling modules in a plugin system.

## Consequences

**Pros:** Components become reusable and testable in isolation. Coordination in one place. Fewer
direct dependencies.

**Cons:** Mediator tends to grow into a God Object absorbing every business rule. Shifts complexity
rather than eliminating it.

## When NOT to use

- Components interact a little, or via natural parent-child paths.
- You only have two components — a Mediator is always overkill for two.

## Modern relevance

Conceptually central, nominally rare. Redux/Zustand/Pinia stores are mediators — components
dispatch actions, the store coordinates, components subscribe to slices. Message buses, event
aggregators, orchestration services in microservices are Mediators at larger scale. The
"controller" in MVC is Mediator-adjacent.

## Code sketch (TypeScript)

```ts
interface Mediator { notify(sender: object, event: string): void }

class Form implements Mediator {
  constructor(public checkbox: Checkbox, public field: Field) {
    checkbox.mediator = this; field.mediator = this
  }
  notify(sender: object, event: string) {
    if (sender === this.checkbox && event === "toggle") {
      this.field.visible = this.checkbox.checked
    }
  }
}
class Checkbox {
  mediator!: Mediator; checked = false
  toggle() { this.checked = !this.checked; this.mediator.notify(this, "toggle") }
}
class Field { mediator!: Mediator; visible = false }
```

## Real-world uses

- Redux/Flux stores (components → store → components)
- Rails ActionCable channels
- Message brokers (RabbitMQ, Kafka as service-level mediator)
- Air-traffic controllers in simulations
- Chat servers
- Form controllers
- Orchestration layers in microservice architectures

## Distinguishing from neighbors

- **vs. Observer** — Observer is one-to-many broadcast with publishers unaware of subscribers.
  Mediator is a hub where *all* component-to-component traffic funnels through a coordinator that
  knows everyone. Mediator is often *implemented* using Observer.
- **vs. Facade** — Facade presents a simpler entry-point to a subsystem that talks internally
  however it wants. Mediator *forces* components to go through it.

## Functional equivalent

Reducer function `(state, event) => state` + pub/sub store. Redux is this.

## Rule of thumb

If components need to talk to each other, ask: is the coordination logic non-trivial? If yes,
Mediator. If it's just "A fires, B reacts," Observer is lighter. Watch for God Object drift —
split the Mediator by domain (form mediator, shopping cart mediator) rather than having one.
