# Memento

**Category:** Behavioral · **Modern relevance:** High (undo, time travel, transactions)

## Intent

Capture and externalize an object's internal state so it can be restored later, without breaking
encapsulation.

## Problem

You want undo, snapshots, or transactional rollback. Naive implementations either expose internals
publicly (breaking encapsulation) or force callers to know state layout (coupling).

## Structure

- **Originator** creates a memento containing its current state and restores from one.
- **Memento** is an opaque value object. Ideally only the originator sees contents; caretakers
  only hold it.
- **Caretaker** keeps mementos (history stack) but never inspects them.

## Applicability

- Undo/redo (paired with Command).
- Transactional operations that must roll back on failure.
- Snapshots for debugging or time-travel.
- Saving game or document state.

## Consequences

**Pros:** Preserves encapsulation. Externalizes history. Supports undo/redo/rollback cleanly.

**Cons:** Memory cost grows with snapshots. Requires lifecycle management of old mementos.
Languages like JS/Python can't truly enforce memento opacity.

## When NOT to use

- Tiny value objects — cloning is simpler than a memento class.
- Originator is already immutable — every reference is a memento; you don't need the pattern.

## Modern relevance

The idea is ubiquitous; the OO class ceremony is rare. Redux DevTools time-travel, immutable state
snapshots, database transactions, Git commits, VM snapshots, document versioning, event-sourcing
rebuilds — all variations. Immutable data + history array replaces the formal pattern.

## Code sketch (TypeScript)

```ts
class Editor {
  private text = ""
  type(s: string) { this.text += s }
  read() { return this.text }
  save(): Snapshot { return new Snapshot(this, this.text) }
  restore(s: Snapshot) { this.text = s.state }
}
class Snapshot { constructor(readonly owner: Editor, readonly state: string) {} }

const ed = new Editor()
ed.type("hello ")
const snap = ed.save()
ed.type("world")
ed.restore(snap)
console.log(ed.read())  // "hello "
```

## Real-world uses

- Undo stacks in editors (Photoshop, VSCode)
- Redux time-travel debugging
- Database transactions (rollback = restore a memento)
- Game save states
- Git's object store
- Filesystem snapshots (ZFS)
- VM snapshots

## Distinguishing from neighbors

- **vs. Command** — Memento stores state; Command stores an operation. Command + Memento = robust
  undo (undo by restoring the prior memento).
- **vs. Prototype** — Prototype clones for duplication; Memento clones for rollback.

## Functional equivalent

Immutable data + history array. Every old reference is a free memento. Redux is this pattern
realized functionally.

## Rule of thumb

If your data is immutable, you have Memento for free. If it's mutable and you need undo/rollback,
add a Memento class (or a snapshot function). Watch memory — prune old snapshots.
