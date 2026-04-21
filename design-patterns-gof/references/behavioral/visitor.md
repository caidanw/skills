# Visitor

**Category:** Behavioral · **Modern relevance:** Niche (compilers). Prefer pattern matching.

## Intent

Separate an algorithm from the object structure it operates on, so new operations can be added
without modifying the structure's classes.

## Problem

A heterogeneous object graph (AST nodes, shapes in a CAD program, documents with
headings/paragraphs/images) needs new operations (serialize, render, stats, XML export) without
polluting those classes with every new concern.

## Structure

- **Element** interface with `accept(visitor)`.
- **Concrete Elements** implement `accept` by calling the visitor method specific to their type:
  `visitor.visitFoo(this)` — the **double dispatch**.
- **Visitor** interface declares `visitX` for each element type.
- **Concrete Visitors** implement one operation across all element types.

## Applicability

- Stable class hierarchy, unstable set of operations (the exact inversion of what subclasses solve).
- Walking ASTs in compilers/transpilers (type-check, codegen, pretty-print).
- Accumulating computations across trees/graphs.

## Consequences

**Pros:** Adding operations doesn't touch element classes. Related behavior is consolidated per
visitor. Respects open/closed for *operations*.

**Cons:** Adding a new *element type* forces updates to every visitor — closed-world assumption.
Double dispatch is alien to newcomers. Visitors often can't see element internals and need
accessors that partly defeat encapsulation.

## When NOT to use

- Element hierarchy changes more than operations — you've chosen the wrong axis.
- Single operation — a simple recursive function beats the pattern.
- Flat data — pattern matching / discriminated unions are simpler and safer.

## Modern relevance

Niche. Most famous in compilers and AST libraries (TypeScript compiler, Babel, Roslyn, Rust `syn`,
LLVM passes). Languages with pattern matching (Rust `match`, Swift `switch`, TS discriminated
unions, Python 3.10 `match`) largely replace Visitor with exhaustive matching. Still handy when
the operation must be *injected by users* of a fixed AST, which is why compiler plugin systems
expose visitor APIs.

## Code sketch (TypeScript — as a record of handlers over a union)

```ts
type Expr =
  | { kind: "num"; val: number }
  | { kind: "add"; l: Expr; r: Expr }
  | { kind: "mul"; l: Expr; r: Expr }

type Visitor<R> = { num(n: number): R; add(l: R, r: R): R; mul(l: R, r: R): R }

const walk = <R>(e: Expr, v: Visitor<R>): R => {
  switch (e.kind) {
    case "num": return v.num(e.val)
    case "add": return v.add(walk(e.l, v), walk(e.r, v))
    case "mul": return v.mul(walk(e.l, v), walk(e.r, v))
  }
}

const evalV:  Visitor<number> = { num: n => n, add: (a,b) => a+b, mul: (a,b) => a*b }
const printV: Visitor<string> = { num: n => `${n}`, add:(a,b)=>`(${a}+${b})`, mul:(a,b)=>`(${a}*${b})` }
```

## Real-world uses

- AST traversal in TypeScript compiler, Babel, Roslyn, Clang
- Swift `SyntaxVisitor`
- SQL query planners
- IDE inspections and refactors
- Accounting reports over account trees
- Tax calculators

## Distinguishing from neighbors

- **vs. Iterator** — Iterator gives you elements; Visitor does type-specific dispatch. They combine.
- **vs. Strategy** — Strategy swaps one operation over one input type. Visitor does one operation
  over many element types.
- **vs. Interpreter** — Interpreter bakes evaluation into nodes; Visitor externalizes it. Visitor
  wins once you have multiple operations over the same AST.

## Functional equivalent

Discriminated unions + exhaustive pattern matching (Rust `match`, TS `switch` on `kind`, Swift
`switch` on enum). Much more ergonomic than OO Visitor. The `walk` function above *is* Visitor
without the `accept` ceremony.

## Rule of thumb

If you have an AST (or tree with fixed types) and multiple operations over it, reach for
pattern matching. Use formal `accept(visitor)` only when you're building a framework whose users
will extend it with their own operations and you can't change the AST classes.
