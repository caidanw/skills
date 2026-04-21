# Iterator

**Category:** Behavioral · **Modern relevance:** Built into every modern language

## Intent

Provide a uniform way to traverse a collection's elements without exposing its internal structure.

## Problem

Collections differ (array, linked list, tree, graph, paginated remote source). Clients want uniform
access. Baking traversal into each collection class bloats it and couples clients to structure.

## Structure

- **Iterator** interface with `next()`/`hasNext()` (or a `done`/`value` shape).
- **Concrete Iterator** tracks position and traversal algorithm.
- **Aggregate/Collection** exposes a factory (`iterator()`) for iterators.
- **Client** works against iterator interface only.

## Applicability

- Traversing complex structures (trees, graphs) without exposing layout.
- Multiple traversal orders (pre-order, in-order, BFS, DFS).
- Lazy/streaming sequences where materializing everything is expensive.
- Parallel independent cursors over one collection.

## Consequences

**Pros:** Decouples traversal from container. Enables lazy evaluation. Multiple concurrent cursors.
SRP.

**Cons:** Overkill for arrays. Can be less efficient than direct indexing. Extra object per
traversal.

## When NOT to use

- A `for` loop over an array/map does the job.
- Defining a `CarCollectionIterator` class today is almost always waste.

## Modern relevance

Built into every modern language. `Iterable`/`Iterator` protocol in JS/TS. `__iter__`/`__next__` in
Python. `IEnumerable` in C#. `Iterator` trait in Rust. Generators (`function*`, `yield`) are
Iterator as syntax. LINQ, comprehensions, Rust iterator adapters, Java Streams — all iterator-based.
You use it every `for…of` loop.

## Code sketch (TypeScript — generator)

```ts
type Node<T> = { value: T; left?: Node<T>; right?: Node<T> }

function* inOrder<T>(n: Node<T> | undefined): Iterable<T> {
  if (!n) return
  yield* inOrder(n.left)
  yield n.value
  yield* inOrder(n.right)
}

const tree: Node<number> = {
  value: 2,
  left:  { value: 1 },
  right: { value: 3 },
}

for (const v of inOrder(tree)) console.log(v)  // 1, 2, 3
```

## Real-world uses

- Every `for…of`/`for…in`
- Python generators, comprehensions
- LINQ, Java Streams, Rust iterators
- Database cursors, paginated API clients
- File line readers, directory walkers

## Distinguishing from neighbors

- **vs. Visitor** — Iterator yields nodes so the *caller* operates on them. Visitor *dispatches* an
  operation to each node via double dispatch. Often combined: iterate to yield, visit to handle.

## Functional equivalent

Generators, lazy sequences, transducers. `map`/`filter`/`reduce` chains are iterator-backed.

## Rule of thumb

Don't write an Iterator class in 2026. Use your language's iterator protocol and generators. The
pattern name is useful for talking about *lazy traversal semantics*; the class ceremony is obsolete.
