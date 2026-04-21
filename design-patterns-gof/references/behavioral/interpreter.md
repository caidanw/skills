# Interpreter

**Category:** Behavioral · **Modern relevance:** Low. Prefer parser combinators + ADTs.

## Intent

Given a language, define a representation of its grammar plus an interpreter that evaluates
sentences in that language.

## Problem

A domain has a recurring, well-understood set of problems expressible as a small language
(arithmetic expressions, query filters, routing rules, validation rules). Hard-coding each instance
is repetitive.

## Structure

- **Abstract Expression** interface with `interpret(context)`.
- **Terminal Expression** for leaves (literals, variables).
- **Non-terminal Expression** for composite rules (Add, And, Or). Usually Composite-shaped.
- **Context** carries external state (variable bindings, I/O).
- **Client** builds an AST and calls `interpret(ctx)`.

## Applicability

- Small, stable DSL with a simple grammar (boolean expressions, arithmetic, glob patterns, query
  filters).
- The language is embedded rather than parsed from text — the pattern covers evaluation, not parsing.
- Grammar evolves slowly.

## Consequences

**Pros:** Each grammar rule is a single, testable class. Easy to add new rule types.

**Cons:** Class explosion as grammar grows. Performance is poor vs. compiled or table-driven
approaches. Parsing is out of scope. Complex grammars outgrow the pattern quickly.

## When NOT to use

- Any grammar richer than a handful of operators — reach for parser generators (ANTLR, tree-sitter,
  nearley, Lark), parser combinators, or PEG libraries.
- A lookup table or simple switch captures the domain — do that.

## Modern relevance

The *least* modern GoF pattern by name. Everyone builds DSLs, but via parser combinators,
tree-sitter, or embedded-DSL techniques — not per-rule classes. Shows up implicitly inside
filter/query builders (MongoDB query documents, Elasticsearch DSL, SQLAlchemy expressions,
Drizzle), spreadsheet formula engines, rule engines (Drools), configuration evaluators. Functional
languages implement this as algebraic data types with a single `eval` function.

## Code sketch (TypeScript)

```ts
type Ctx = Record<string, number>
type Expr =
  | { kind: "lit"; v: number }
  | { kind: "var"; name: string }
  | { kind: "add"; l: Expr; r: Expr }
  | { kind: "mul"; l: Expr; r: Expr }

const interpret = (e: Expr, ctx: Ctx): number => {
  switch (e.kind) {
    case "lit": return e.v
    case "var": return ctx[e.name] ?? 0
    case "add": return interpret(e.l, ctx) + interpret(e.r, ctx)
    case "mul": return interpret(e.l, ctx) * interpret(e.r, ctx)
  }
}

// (x + 2) * 3 where x = 4  =>  18
const ast: Expr = {
  kind: "mul",
  l: { kind: "add", l: { kind: "var", name: "x" }, r: { kind: "lit", v: 2 } },
  r: { kind: "lit", v: 3 },
}
interpret(ast, { x: 4 })
```

## Real-world uses

- Small regex engines
- SQL query ASTs
- MongoDB query operators
- ORM expression trees (SQLAlchemy, Drizzle, LINQ)
- Feature-flag rule engines
- Spreadsheet formulas
- CSS selector evaluation
- Shell glob matching

## Distinguishing from neighbors

- **vs. Visitor** — Interpreter bakes evaluation into each node class. Visitor externalizes
  operations. Once you have multiple operations over the AST (eval, pretty-print, optimize,
  type-check), Visitor (or pattern matching) wins.
- **vs. Composite** — Interpreter's expression tree *is* Composite; Interpreter adds the
  `interpret` semantic.

## Functional equivalent

Algebraic data type (tagged union) + recursive `eval`. Exactly how modern compilers and query
engines are written. The code sketch above is this equivalent.

## Rule of thumb

For any non-trivial grammar, use a parser library + an ADT + a single `eval` (which is really
Visitor under a different name). Reach for formal Interpreter only when the set of rules is tiny,
fixed, and you want each rule to be independently extensible as a class.
