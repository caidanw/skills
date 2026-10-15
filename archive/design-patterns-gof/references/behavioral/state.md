# State

**Category:** Behavioral · **Modern relevance:** High (XState, typestate, UI state machines)

## Intent

Let an object alter its behavior when its internal state changes — so it appears to change class —
by delegating to separate state objects.

## Problem

A class has a `state` field and every method begins with `switch (this.state)`. Adding a state
means editing every method. Transitions are scattered. The conditional monster grows unbounded.

## Structure

- **Context** holds a reference to a current state object and delegates state-sensitive operations.
- **State** interface declares the operations.
- **Concrete States** implement each operation for their state and trigger transitions by swapping
  the context's state.

## Applicability

- Protocols with distinct phases and rules (TCP: Closed/Listen/SynSent/Established).
- UI modes (selection vs drawing vs pan tool).
- Order/workflow lifecycles (Draft → Submitted → Approved → Shipped).
- Game entity behaviors (Idle, Patrol, Attack, Dead).

## Consequences

**Pros:** Eliminates giant conditionals. Each state class is focused. Transitions are explicit.
Easy to add new states.

**Cons:** One class per state — heavy for tiny behaviors. Transitions sprayed across state classes
can be hard to follow. Overkill for 2-state flags.

## When NOT to use

- Boolean or two-value flag — a conditional is clearer.
- States are stable and few — a single switch is fine.

## Modern relevance

Very alive, especially in UI. Finite state machines and state charts drive robust UIs: XState
(TS), Stately, Ragel, Erlang's `gen_statem`, Rust's typestate pattern, SwiftUI enum-driven views.
Complex form wizards, payment flows, async request lifecycles (idle/loading/success/error) are
explicit state machines. Redux Toolkit + discriminated unions is State-flavored.

## Code sketch (TypeScript — discriminated union form)

```ts
type State =
  | { kind: "idle" }
  | { kind: "loading" }
  | { kind: "success"; data: string }
  | { kind: "error"; msg: string }

type Event =
  | { type: "fetch" } | { type: "ok"; data: string } | { type: "fail"; msg: string }

const reduce = (s: State, e: Event): State => {
  switch (s.kind) {
    case "idle":    return e.type === "fetch" ? { kind: "loading" } : s
    case "loading": return e.type === "ok"   ? { kind: "success", data: e.data }
                         : e.type === "fail" ? { kind: "error", msg: e.msg } : s
    default:        return s
  }
}
```

## Real-world uses

- TCP state machines
- React component loading states
- XState-driven UIs
- Game AI behavior trees / FSMs
- Order/workflow engines
- Parsers, regex engines
- Vending machines
- Stripe payment intents
- Job schedulers

## Distinguishing from neighbors

- **vs. Strategy** — Both swap behavior via composition. Strategy: *client* picks the algorithm;
  strategies are independent. State: transitions happen *internally*; states often know about each
  other. Heuristic: Strategy = *how*. State = *where in its lifecycle*.
- **vs. Command** — Command is a request object; State is internal behavior mode.

## Functional equivalent

Reducer `(state, event) => state` with discriminated union. This is how modern TS codebases do it —
no state classes. XState adds hierarchical states, parallel regions, and guards on top.

## Rule of thumb

For >3 states or complex transitions, reach for an explicit state machine (XState, Zustand with
discriminated union, typestate). For 2 states, a boolean is fine. Put transitions in **one place**,
not scattered across state classes.
