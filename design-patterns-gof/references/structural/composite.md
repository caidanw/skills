# Composite

**Category:** Structural · **Modern relevance:** Ubiquitous (DOM, ASTs, scene graphs)

## Intent

Let clients treat individual objects and compositions of objects uniformly by giving them a shared
interface and recursing through a tree.

## Problem

Hierarchical data (files/folders, UI trees, org charts, boxes of boxes of products) where code
needs to compute aggregates or apply operations without branching on "is this a leaf or a branch?"
everywhere.

## Structure

- **Component** — common interface for leaves and composites.
- **Leaf** — does the actual work; no children.
- **Composite (Container)** — holds children, delegates operations, aggregates results.
- **Client** — works against `Component` only.

## Applicability

- Your domain *is* a tree (DOM, AST, filesystem, scene graph).
- Clients must treat one and many the same (`render()`, `price()`, `size()`).

## Consequences

**Pros:** Polymorphic recursion replaces type-switches. Open/Closed for new node types.

**Cons:** Leaves and composites may not genuinely share an interface — you end up with
`add()`/`remove()` on leaves throwing `UnsupportedOperationException`. The interface grows overly
general.

## When NOT to use

- The structure isn't actually recursive — it's just a list.
- Leaf and container operations diverge sharply; forcing a shared interface lies about the domain.
- Only one consumer needs aggregation — inline the recursion.

## Modern relevance

Extremely high. The DOM is Composite. React/Vue component trees are Composite. ASTs (Babel,
TypeScript, Rust's `syn`) are Composite. File systems. GUI layout trees (SwiftUI `View`, Flutter
`Widget`, AppKit `NSView`). So pervasive it's invisible.

## Code sketch (TypeScript)

```ts
interface FsNode { name: string; size(): number }

class File implements FsNode {
  constructor(public name: string, private bytes: number) {}
  size() { return this.bytes }
}

class Directory implements FsNode {
  private children: FsNode[] = []
  constructor(public name: string) {}
  add(n: FsNode) { this.children.push(n) }
  size() { return this.children.reduce((s, c) => s + c.size(), 0) }
}

const root = new Directory("root")
root.add(new File("a.txt", 100))
const sub = new Directory("sub"); sub.add(new File("b.txt", 50))
root.add(sub)
console.log(root.size()) // 150
```

## Real-world uses

- DOM, React fiber tree
- AST libraries (TypeScript compiler, Babel, Rust `syn`)
- `java.awt.Container` hierarchy
- Unity/Unreal scene graphs
- AppKit/UIKit view hierarchies

## Distinguishing from neighbors

- **vs. Decorator** — Same reference-to-same-interface shape. Decorator has *one* wrapped child and
  adds behavior; Composite has *many* children and aggregates.
- **vs. Visitor** — Composite defines the structure; Visitor defines operations over it. They pair
  naturally.

## Rule of thumb

If your data is a tree, model it as Composite. Push the leaf/branch distinction into the type, not
into consumers. This is the one pattern that's almost never over-abstraction — if the domain is a
tree, you *need* the shape.
