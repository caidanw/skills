# Builder

**Category:** Creational · **Modern relevance:** High (usually as fluent APIs or options objects)

## Intent

Separate the **construction** of a complex object from its representation, so the same construction
process can produce different representations — and callers don't pass 14 positional arguments.

## Problem

Telescoping constructors. A `House` needs walls, doors, windows, a roof, optionally a pool, a
garage, a garden. `new House(4, 2, true, false, null, true, "brick", ...)` is unreadable. Subclassing
per configuration (`HouseWithPool`, `HouseWithPoolAndGarage`) explodes combinatorially.

## Structure

- **Builder interface** — declares step methods (`buildWalls()`, `buildRoof()`, …) and `getResult()`.
- **Concrete Builders** — `StoneHouseBuilder`, `WoodenHouseBuilder`.
- **Product** — the thing being built; different builders may produce unrelated types.
- **Director (optional)** — encodes *recipes* by sequencing builder calls.
- **Client** — picks a builder (and optionally a director), retrieves the result.

In practice, most modern implementations skip the Director and use a **fluent interface**:
`new QueryBuilder().select("id").from("users").where("active").build()`.

## Applicability

- Objects with many optional parameters.
- Immutable objects that need a staging ground before sealing.
- Constructing the same logical object in multiple representations (shared `HtmlReportBuilder` and `PdfReportBuilder`).
- Parsing DSLs or configuration incrementally.
- Recursive construction of trees (AST nodes, UI component trees).

## Consequences

**Pros:** Readable call sites. Optional parameters are natural. Immutable results. Reusable
construction logic. Method chaining is ergonomic.

**Cons:** More classes/boilerplate. Two-phase object existence (builder + product) leaks if you use
the builder after `build()`. Required fields can be hard to enforce at compile time in some languages.

## When NOT to use

- Your object has ≤3 parameters. Use a constructor or options object.
- In TS/Python, **keyword arguments + defaults + `Partial<Options>`** already solve this. A Builder
  class there is ceremony.
- One-shot construction at startup from config — parse the config directly.

## Modern relevance

The explicit GoF Director-based Builder is rare. What's everywhere: fluent APIs (SQL query builders,
HTTP request builders, test data factories) and options objects. In TS/Python, options-object-with-
defaults is idiomatic. In Rust, Builder is **canonical** because the language lacks named arguments.

## Code sketch (TypeScript — fluent builder)

```ts
class QueryBuilder {
  private parts = { select: ["*"], from: "", where: [] as string[], limit: -1 }

  select(...cols: string[]) { this.parts.select = cols; return this }
  from(table: string)        { this.parts.from = table; return this }
  where(cond: string)        { this.parts.where.push(cond); return this }
  limit(n: number)           { this.parts.limit = n; return this }

  build(): string {
    const { select, from, where, limit } = this.parts
    let sql = `SELECT ${select.join(", ")} FROM ${from}`
    if (where.length) sql += ` WHERE ${where.join(" AND ")}`
    if (limit > 0)    sql += ` LIMIT ${limit}`
    return sql
  }
}

const sql = new QueryBuilder().from("users").where("active = 1").limit(10).build()
```

## Code sketch (TypeScript — options object, the usual winner)

```ts
type HouseOpts = { walls: number; doors?: number; pool?: boolean; garage?: boolean }

function buildHouse({ walls, doors = 1, pool = false, garage = false }: HouseOpts) {
  return { walls, doors, pool, garage }
}

buildHouse({ walls: 4, pool: true })
```

## Real-world uses

- Java `StringBuilder`, `Stream.Builder`
- Rust `std::process::Command`, `reqwest::ClientBuilder`
- Kotlin DSLs (`buildString { ... }`, Jetpack Compose)
- SQL builders: Knex, Kysely, SQLAlchemy Core, Drizzle
- Protobuf message builders in Java/Go
- AWS CDK construct chains

## Distinguishing from neighbors

- **vs. Abstract Factory** — Builder produces **one** complex object step-by-step; Abstract Factory
  produces several related objects in one shot.
- **vs. Factory Method** — Factory Method returns a finished product; Builder exposes intermediate
  construction state.

## Rule of thumb

4+ optional parameters, or compile-time required-field enforcement needed → Builder. 3 or fewer →
options object. In Rust, Builder for anything non-trivial.
