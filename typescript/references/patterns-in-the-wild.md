# TypeScript Patterns in the Wild

How the best TypeScript codebases actually write code. Patterns extracted from Zod, tRPC, Hono, TanStack Query, ts-pattern, and neverthrow.

## Classes for Fluent APIs (Zod, Hono)

The "no classes" rule doesn't hold for chainable APIs. Zod, Hono, and TanStack Query all use classes — methods return `this` or new instances, enabling type-safe chaining.

```ts
// Zod-style schema builder — classes make chaining natural
class Schema<T> {
  // Each method returns a new Schema with a narrower type
  optional(): Schema<T | undefined> { /* ... */ }
  default(value: T): Schema<T> { /* ... */ }
  transform<U>(fn: (val: T) => U): Schema<U> { /* ... */ }
}

// Usage reads naturally
const schema = z.string().min(3).max(50).optional()
```

**When classes work:** Builder patterns, schema validators, query builders, HTTP framework cores — anywhere chaining is the primary API surface.

**When classes don't work:** Business logic, data transformations, utilities — use factory functions and plain objects.

## Zero Dependencies (Zod, Hono, ts-pattern, neverthrow)

Every top TypeScript library ships zero dependencies. They inline utilities, own their entire stack, and keep bundles small.

```ts
// Instead of: npm install lodash.pick
function pick<T, K extends keyof T>(obj: T, keys: K[]): Pick<T, K> {
  const result = {} as Pick<T, K>
  for (const key of keys) result[key] = obj[key]
  return result
}
```

**Benefits:** Smaller bundles, no supply chain risk, faster installs, full control.

## End-to-End Type Safety Without Codegen (tRPC)

tRPC's key insight: TypeScript's type inference can flow from server to client without code generation.

```ts
// Server — define a procedure with Zod input validation
const appRouter = t.router({
  getUser: t.procedure
    .input(z.object({ id: z.string() }))
    .query(({ input }) => {
      return db.user.findUnique({ where: { id: input.id } })
    }),
})

// Export only the type — no runtime code crosses the boundary
export type AppRouter = typeof appRouter

// Client — fully typed, no codegen step
const user = await trpc.getUser.query({ id: "123" })
//    ^? User | null — inferred from server implementation
```

**Key pattern:** Use `typeof` to export type information from runtime code. The server implementation IS the type definition.

## Exhaustive Pattern Matching (ts-pattern)

ts-pattern provides compile-time exhaustive matching — cleaner than switch statements for complex discriminated unions.

```ts
import { match, P } from "ts-pattern"

type Event =
  | { type: "click"; x: number; y: number }
  | { type: "keydown"; key: string }
  | { type: "scroll"; delta: number }

const label = match(event)
  .with({ type: "click" }, ({ x, y }) => `Click at ${x},${y}`)
  .with({ type: "keydown" }, ({ key }) => `Key: ${key}`)
  .with({ type: "scroll" }, ({ delta }) => `Scroll: ${delta}`)
  .exhaustive() // compile error if a case is missing
```

**When to use:** Complex state machines, event handlers, AST visitors — anywhere you have many variants and need guaranteed coverage. For simple 3-4 case switches, plain `switch` with `assertNever` in the default is fine.

## Result Types Without FP Jargon (neverthrow)

neverthrow implements the Result pattern without monad terminology. It's the practical middle ground between try/catch and full Effect-TS.

```ts
import { ok, err, Result } from "neverthrow"

function parseConfig(raw: string): Result<Config, ParseError> {
  try {
    const parsed = JSON.parse(raw)
    if (!parsed.host) return err(new ParseError("missing host"))
    return ok(parsed as Config)
  } catch {
    return err(new ParseError("invalid JSON"))
  }
}

// Caller must handle both paths — can't accidentally ignore errors
const result = parseConfig(input)
if (result.isOk()) {
  startServer(result.value)
} else {
  console.error(result.error.message)
}
```

**When to use:** Parsing, validation, API calls — expected failures where you want the type system to force handling. Use `throw` for truly exceptional/unexpected errors.

## `as const` Object Maps (universal pattern)

Every top codebase uses `as const` objects instead of enums:

```ts
const HttpMethod = {
  GET: "GET",
  POST: "POST",
  PUT: "PUT",
  DELETE: "DELETE",
} as const

type HttpMethod = typeof HttpMethod[keyof typeof HttpMethod]
// "GET" | "POST" | "PUT" | "DELETE"
```

**Advantages over enums:**
- Zero runtime overhead (enums emit code)
- Works with `--erasableSyntaxOnly`
- Tree-shakeable
- Structural typing (no need to import the enum to pass a valid value)

## Discriminated Unions at Scale (TanStack Query)

TanStack Query models all async state as discriminated unions. Every consumer handles each state explicitly:

```ts
type QueryResult<T> =
  | { status: "pending"; fetchStatus: "idle" | "fetching" }
  | { status: "error"; error: Error; fetchStatus: "idle" | "fetching" }
  | { status: "success"; data: T; fetchStatus: "idle" | "fetching" }

// Usage forces handling each state
const query = useQuery({ queryKey: ["user"], queryFn: fetchUser })

switch (query.status) {
  case "pending": return <Spinner />
  case "error": return <ErrorDisplay error={query.error} />
  case "success": return <UserCard user={query.data} />
}
```

**Key insight:** The discriminant (`status`) determines which fields exist. No optional fields, no `data?: T`, no `error?: Error`. Each state carries exactly what it needs.

## Type-Safe Middleware (Hono)

Hono chains middleware with type-safe context accumulation — each middleware adds to the context type:

```ts
const app = new Hono()
  .use(authMiddleware)     // adds { user: User } to context
  .use(rateLimitMiddleware) // adds { rateLimit: RateLimitInfo } to context
  .get("/me", (c) => {
    // c.var.user and c.var.rateLimit are both typed
    return c.json({ user: c.var.user })
  })
```

**Pattern:** Each middleware returns a new type that extends the previous context. The final handler has access to all accumulated types.

## Sources

- [Zod](https://github.com/colinhacks/zod) — Schema validation, chainable class API
- [tRPC](https://github.com/trpc/trpc) — End-to-end type safety without codegen
- [Hono](https://github.com/honojs/hono) — Lightweight web framework, typed middleware
- [TanStack Query](https://github.com/TanStack/query) — Async state as discriminated unions
- [ts-pattern](https://github.com/gvergnaud/ts-pattern) — Exhaustive pattern matching
- [neverthrow](https://github.com/supermacro/neverthrow) — Result types without FP jargon
- [Matt Pocock / Total TypeScript](https://www.totaltypescript.com) — type vs interface, return types, erasableSyntaxOnly
- [TypeScript Performance Wiki](https://github.com/microsoft/TypeScript/wiki/Performance) — Compilation performance
