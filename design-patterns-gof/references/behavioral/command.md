# Command

**Category:** Behavioral · **Modern relevance:** High (CQRS, Redux actions, job queues)

## Intent

Encapsulate a request as a standalone object containing all information to execute it later,
pass it around, queue it, log it, or undo it.

## Problem

Invokers (buttons, menus, keyboard shortcuts, CLI parsers, job queues) would otherwise need to know
business-logic details. You need to parameterize invocations, delay them, persist them, retry them,
or reverse them.

## Structure

- **Command** interface with `execute()` (optionally `undo()`).
- **Concrete Command** binds a receiver plus parameters.
- **Receiver** contains actual business logic.
- **Invoker** holds and triggers commands without knowing what they do.
- **Client** wires commands to invokers.

## Applicability

- Undo/redo stacks.
- Queued/deferred/scheduled execution (job queues, schedulers).
- Operation logging for audit or replay (event sourcing).
- Remote execution — command must serialize over the wire.
- Macro commands composed from simpler ones.

## Consequences

**Pros:** Decouples invoker from receiver. Supports undo, queueing, logging, transactions.
Composable.

**Cons:** One class per operation bloats naive implementations. Extra indirection.

## When NOT to use

- Simple synchronous button clicks. No undo/queueing/logging/remote needed — a plain function call
  wins.
- Not every handler needs to become a `FooCommand` class.

## Modern relevance

Pattern is central, just not as classes. CQRS architectures, Redux actions, React Server Actions,
message queues (SQS, Kafka messages), job runners (Sidekiq, Celery, BullMQ jobs), database
migrations, every event-sourced system are Command-shaped. In modern code a command is usually a
serializable data object plus a handler function, not an OO class with `execute()`.

## Code sketch (TypeScript)

```ts
type Command = { do: () => void; undo: () => void }

class History {
  private stack: Command[] = []
  private redo: Command[] = []
  run(c: Command) { c.do(); this.stack.push(c); this.redo = [] }
  undo() { const c = this.stack.pop(); if (c) { c.undo(); this.redo.push(c) } }
  redoLast() { const c = this.redo.pop(); if (c) { c.do(); this.stack.push(c) } }
}

const makeAddText = (doc: string[], text: string): Command => ({
  do:   () => doc.push(text),
  undo: () => doc.pop(),
})

const doc: string[] = []
const h = new History()
h.run(makeAddText(doc, "hello "))
h.run(makeAddText(doc, "world"))
h.undo()  // doc === ["hello "]
```

## Real-world uses

- Undo/redo in editors (Photoshop, VSCode)
- Redux/Flux actions, CQRS commands
- Event sourcing — commands + events
- Git commits
- Database migrations
- Job queues (Sidekiq, Celery, BullMQ)
- Macro recording, keybinding systems

## Distinguishing from neighbors

- **vs. Strategy** — Strategy swaps *how* one thing is done (usually stateless). Command packages a
  specific *what to do* with parameters.
- **vs. Memento** — Command encapsulates an operation; Memento snapshots state. They pair: log a
  command + a pre-state memento = undo.
- **vs. Chain of Responsibility** — CoR is sequential handler lookup; Command is a request object
  that any handler might process.

## Functional equivalent

Closure or `{ type, payload }` + handler map. Redux actions + reducers are textbook functional
Command.

## Rule of thumb

Use Command (named pattern, not necessarily classes) when you need any of: **queue, persist, log,
retry, undo, remote**. If you need none of those, a function call is clearer.
