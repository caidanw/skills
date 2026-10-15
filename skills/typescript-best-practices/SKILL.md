---
name: typescript-best-practices
description: "TypeScript best practices: simple, composable, soundly typed code, with rules for unions, branded types, parsing, narrowing, casts, exhaustiveness, errors, and the TS 6/7 compiler baseline. Use when reading or editing .ts or .tsx files, reviewing TypeScript, or deciding how to model types, errors, and modules in TypeScript."
globs: ["*.ts", "*.tsx", "*.mts", "*.cts"]
---

# TypeScript Best Practices

Write TypeScript that is **simple, clear, composable, and soundly typed**. Use the good parts of functional style — small functions, higher-order functions, discriminated unions, composition — without dogma. Mutate when it's simpler. Be explicit, not clever. Prioritize readability over density.

## Rules at a Glance

The language-agnostic type rules (illegal states, branding, parsing at boundaries, exhaustiveness) live in the **type-system-discipline** skill. The TypeScript form of each is below. Code for every row: [references/rule-examples.md](references/rule-examples.md).

| Rule | Summary |
|------|---------|
| Discriminated unions | Model variants with one literal discriminant (`kind`) so impossible states can't be represented. No optional-field bags. |
| Branded types | Brand primitives with `& { readonly __brand: "X" }` so they can't be mixed up. Validate once at the boundary. |
| Constructive modeling | Build the shape so the illegal value can't be constructed: `[T, ...T[]]` for non-empty, `[T, T][]` for pairs, `start` plus `duration` for a range. |
| Simplest total type | Keep `T[]` while every operation on it stays total. Strengthen to `NonEmpty<T>` only where the loose type forces `!`, a cast, or a "should never happen" throw. |
| `unknown` over `any` | External data is `unknown` until parsed. |
| Schemas before guards | Before hand-writing a property-by-property type guard, use the repo's schema library and infer the type from the schema (`z.infer`). Don't add a schema dependency for one guard. |
| No `as` casts | Every `as` is a runtime crash waiting. Cast only after validation. Annotate a validator with the type it proves (`z.ZodType<User>`). |
| Narrowing order | Discriminant switch > `in` > `typeof`/`instanceof` > user-defined type guard > `as`. |
| Honest type guards | A guard must verify its claim. A lying guard is worse than `as`, because the bug hides behind a name that says it's safe. Name them `isX` or `hasX`. |
| Exhaustiveness | `const _exhaustive: never = x` (or `assertNever(x)`) in default arms, so a new variant is a compile error. |
| `satisfies` over `as` | Validates the value without widening literal types. |
| Schema-derived types | Reach for `Pick`, `Omit`, `Parameters`, `ReturnType`, `Awaited`, `typeof`, or generated types before declaring a parallel interface. |
| Object args | Pass one object instead of several same-typed positional args, so order is self-documenting. Skip on hot paths (render loops, tokenizers, parsers). |
| Real tests | Don't mock what you can run. Verify UI in a running build. See the **behavioral-testing** skill. |
| Structured telemetry | Use the project's structured logger with enough context to debug from an id. No `console.log` in shipped code. |

## 1. Simple and Clear

Choose clarity over brevity. Explicit code that's easy to scan beats compact code that requires careful parsing.

```ts
// Good — clear, easy to follow
const activeUsers = users.filter(u => u.status === "active")
const emails = activeUsers.map(u => u.email)

// Fine too — chained when each step is obvious
const emails = users
  .filter(u => u.status === "active")
  .map(u => u.email)

// Bad — too dense, hard to debug
const emails = users.reduce((acc, u) => u.status === "active" ? [...acc, u.email] : acc, [] as string[])
```

Avoid nested ternaries. Use `switch`, `if/else`, or early returns for multiple conditions.

```ts
// Good
switch (status) {
  case "idle": return null
  case "loading": return <Spinner />
  case "error": return <ErrorBanner error={req.error} />
  case "success": return <Data value={req.data} />
}

// Bad
return status === "idle" ? null : status === "loading" ? <Spinner /> : status === "error" ? <ErrorBanner /> : <Data />
```

## 2. Small Functions That Compose

Functions should do one thing and be easy to combine. Name them so the call site reads naturally.

```ts
const isActive = (u: User) => u.status === "active"
const byCreatedDesc = (a: User, b: User) => b.createdAt - a.createdAt

const recentActive = users
  .filter(isActive)
  .sort(byCreatedDesc)
  .slice(0, 10)
```

Extract predicates, comparators, and mappers when they're reused or when inlining them hurts readability. Don't extract trivial one-offs — `u => u.id` is fine inline.

Keep utility functions in the module that uses them. Only pull them out to a shared file when a second consumer actually appears.

## 3. Higher-Order Functions

Functions that take or return functions. Use them naturally — they're just functions.

```ts
// A function that returns a function
function createValidator<T>(rules: ValidationRule<T>[]) {
  return function validate(value: T): string[] {
    return rules
      .map(rule => rule.check(value) ? null : rule.message)
      .filter((msg): msg is string => msg !== null)
  }
}

// A function that wraps another function
function withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
  return fn().catch(err =>
    attempts > 1 ? withRetry(fn, attempts - 1) : Promise.reject(err)
  )
}
```

Keep the types readable. If a generic signature is getting gnarly, break it up — name intermediate types, use interfaces, add a comment. Don't make people squint.

## 4. Mutate When It's Simpler

Don't create new objects for the sake of "immutability." TypeScript creates a lot of garbage when you spread compulsively. Mutate local state freely. Use `readonly` at API boundaries and shared state, not on every field of every type.

```ts
// Good — mutating a local array is fine
function buildIndex(items: Item[]): Map<string, Item> {
  const index = new Map<string, Item>()
  for (const item of items) {
    index.set(item.id, item)
  }
  return index
}

// Good — spreading is fine when it's simple
const updated = { ...user, name: newName }

// Bad — spreading inside a loop creating tons of intermediate objects
const result = items.reduce((acc, item) => ({ ...acc, [item.id]: item }), {})
```

**The real test: does the mutation escape the current scope?** Mutating a local variable inside a function is always fine. Mutating shared state or arguments passed in is almost always a bug waiting to happen.

Use `readonly` where it prevents real bugs — public API return types, shared config, state that shouldn't be touched.

```ts
interface AppConfig {
  readonly apiUrl: string
  readonly features: readonly string[]
}
```

## 5. Make Illegal States Unrepresentable

This is the single most valuable TypeScript pattern. Model your domain with discriminated unions so impossible states can't exist.

```ts
// Good — each state carries exactly the data it needs
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading"; requestId: string }
  | { status: "success"; data: T }
  | { status: "error"; error: Error }

// Bad — boolean soup, impossible combinations representable
interface AsyncState<T> {
  isLoading?: boolean
  isError?: boolean
  data?: T
  error?: Error
  requestId?: string
}
```

If you `switch` on a discriminant at runtime, your types should mirror that structure. Use `never` in the default to ensure exhaustive handling — the compiler catches missing cases:

```ts
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "rect"; width: number; height: number }

function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${x}`)
}

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.radius ** 2
    case "rect": return s.width * s.height
    default: return assertNever(s) // compile error if a case is missing
  }
}
```

Use this for: request states, auth states, form steps, permissions, payment states, message types — anything with distinct modes.

## 6. Parse at the Boundary

Parse untrusted data once, where it enters the system (request bodies, env, files, `JSON.parse`), into precise types. After that, trust the types instead of re-checking.

- **Strengthen inputs, don't weaken outputs.** Require `[T, ...T[]]` instead of accepting `T[]` and returning `T | undefined`.
- **Brand what structure can't express.** `type UserId = string & { readonly __brand: "UserId" }`, created only by a parsing function.
- Use the project's schema library (Zod, Valibot, ArkType) for external data if it has one.

The full treatment (smart constructors, shotgun parsing, boundary discipline, review checklist) is in the **type-system-discipline** skill.

## 7. Types: Precise but Simple

Make types tight — describe exactly what's possible, nothing more. But don't over-engineer the type system. If a type is hard to read, simplify it.

```ts
// Good — narrow string literals
type Method = "GET" | "POST" | "PUT" | "DELETE"
type Status = "active" | "inactive" | "pending"

// Good — satisfies preserves literal types while validating
const routes = {
  home: "/",
  about: "/about",
  user: "/user/:id",
} satisfies Record<string, string>

// Good — simple generics with clear constraints
function pick<T, K extends keyof T>(obj: T, keys: K[]): Pick<T, K> {
  const result = {} as Pick<T, K>
  for (const key of keys) result[key] = obj[key]
  return result
}

// Bad — type gymnastics that nobody can read
type DeepPartialConditionalMappedInferredNested<T> = ...
```

Default to `type`. Use `interface` when you need `extends` — it creates cached, flat object types that the compiler checks faster than `&` intersections. Avoid `interface` as a default because declaration merging (two interfaces with the same name silently merge) causes surprising bugs.

```ts
// type by default — for objects, unions, aliases, computed types
type User = {
  id: UserId
  name: string
  email: EmailAddress
  status: Status
}

type AsyncResult<T> = AsyncState<T>
type UserInput = Omit<User, "id">
type Handler = (req: Request) => Promise<Response>

// interface when you need extends — faster than & intersections
interface HttpError extends Error {
  status: number
  body: unknown
}
```

Use `unknown` over `any`. Narrow with type guards:

```ts
// Type predicates — narrow in .filter(), if blocks, etc.
function isString(val: unknown): val is string {
  return typeof val === "string"
}
const strings = mixed.filter(isString) // string[]

// Assertion functions — narrow or throw
function assertDefined<T>(val: T | undefined, msg: string): asserts val is T {
  if (val === undefined) throw new Error(msg)
}
```

## 8. Factory Functions by Default, Classes When Earned

Use factory functions with closures for configurable, composable objects. Reserve classes for: wrapping resources (DB connections, WebSocket, streams), fluent/chainable APIs (builders, schema validators like Zod), and `Disposable` objects used with `using`.

```ts
// Factory — simple, composable, no `this` headaches
function createFetcher(defaults: FetchOptions = {}) {
  async function request<T>(url: string, opts: FetchOptions = {}): Promise<T> {
    const merged = { ...defaults, ...opts }
    const res = await fetch(url, merged)
    if (!res.ok) throw new HttpError(res.status, await res.text())
    return res.json()
  }

  // Composable — create specialized fetchers
  request.withAuth = (token: string) =>
    createFetcher({ ...defaults, headers: { ...defaults.headers, Authorization: `Bearer ${token}` } })

  return request
}

const api = createFetcher({ baseUrl: "https://api.example.com" })
const authed = api.withAuth(token)
```

### Identity Functions for Type Inference

Functions that return their argument unchanged — their only job is type inference:

```ts
function defineConfig<const T extends AppConfig>(config: T): T {
  return config
}

// The `const` modifier preserves literal types
const config = defineConfig({
  routes: ["/api/users", "/api/posts"],
  features: ["auth", "billing"],
})
// Type preserves the literal string arrays, not just string[]
```

## 9. Useful Patterns

### Result Type (When Appropriate)

For expected failures where you want the caller to handle both paths explicitly. Don't use this everywhere — `throw` is fine for truly exceptional errors.

```ts
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E }

function ok<T>(value: T): Result<T, never> {
  return { ok: true, value }
}

function err<E>(error: E): Result<never, E> {
  return { ok: false, error }
}

function parseConfig(raw: string): Result<Config, string> {
  try {
    const parsed = JSON.parse(raw)
    if (!parsed.host) return err("missing host")
    return ok(parsed as Config)
  } catch {
    return err("invalid JSON")
  }
}
```

### Error Handling

Always type catch block errors as `unknown`, then narrow. Use `Error.cause` for chaining context through layers.

```ts
try {
  await fetchData()
} catch (err) {
  if (err instanceof Error) {
    throw new Error("Failed to load data", { cause: err })
  }
  throw err
}
```

Use Result types for expected failures (above). Use `throw` for truly unexpected errors. Don't mix — pick one strategy per boundary.

## 10. Common Gotchas

Concrete pitfalls that cause runtime bugs despite passing type checks:

- **`Object.keys()` returns `string[]`**, not `(keyof T)[]`. TypeScript can't guarantee an object doesn't have extra keys at runtime. Cast explicitly when safe: `Object.keys(obj) as Array<keyof typeof obj>`.
- **`.filter()` doesn't narrow** without a type predicate. Use `.filter((x): x is T => x !== null)` instead of `.filter(x => x !== null)`.
- **Catch blocks: errors are `unknown`**, not `Error`. Always narrow: `catch (err) { if (err instanceof Error) ... }`.
- **`{}` matches any non-nullish value** — including strings, numbers, and booleans. Use `Record<string, unknown>` for "some object" and `unknown` for "anything."
- **Type widening in conditionals**: `cond ? "a" : "b"` infers as `string`, not `"a" | "b"`. Use `as const` on the branches if you need literals.
- **Method syntax is bivariant**: `{ compare(a: T): number }` skips contravariance checks. Use function property syntax `{ compare: (a: T) => number }` for type safety under `strictFunctionTypes`.

## What NOT to Do

- **No `enum`** — use union types or `as const` objects. Enums are non-erasable syntax: Node's type stripping rejects them, and `--erasableSyntaxOnly` turns them into errors.
- **No `namespace`** — use modules. Also non-erasable.
- **No `I` prefix on interfaces** — just name the thing.
- **No FP ceremony or jargon** — no monads, functors, or applicatives by name. But use practical FP patterns: Result types, pipe composition, exhaustive matching (see `ts-pattern`).
- **No unnecessary abstraction** — three similar lines beats a premature `createGenericHandler`.
- **No `any`** — use `unknown` and narrow, or fix the type.
- **No barrel files with circular re-exports** — they explode module graphs, kill tree-shaking, and slow bundlers/test runners. One barrel at a package root is fine; barrels in every subdirectory are not.
- **No npm packages for 10 lines of code** — inline tiny utils. (Zod, Hono, ts-pattern all ship zero dependencies.)
- **No unsanitized user input** in SQL queries, HTML output, shell commands, or file paths. Use parameterized queries, escaping, and argument arrays at every boundary.

## Style

- `const` everywhere. `let` only for genuine reassignment.
- `type` by default. `interface` only for `extends`. (See Section 7.)
- Declare return types on top-level exported functions — documents the contract, speeds up `.d.ts` emit, and is required by `isolatedDeclarations`. Skip for JSX components.
- Destructure in params when it helps: `({ id, name }: User) => ...`
- Optional chaining and nullish coalescing: `user?.address?.city ?? "Unknown"`
- `function` keyword for named, exported functions. Arrows for inline callbacks and short helpers.
- Trailing commas.
- Template literals over string concatenation.
- `as const` to preserve literal types.
- `satisfies` to validate shape while preserving inference.
- Enable `noUncheckedIndexedAccess` — makes array/object index access return `T | undefined`, catching unsafe assumptions like `arr[0]` or `env.NODE_ENV`.
- Enable `erasableSyntaxOnly` and `verbatimModuleSyntax` — disables enums, namespaces, and parameter properties, and forces `import type`. Code then runs under Node's type stripping (`node file.ts`).

## Compiler Baseline (TS 6 / TS 7)

TS 6.0 changed defaults and TS 7.0 (the native Go compiler) removes the deprecated options:

- `strict` is on by default. Keep `noUncheckedIndexedAccess` on as well.
- `types` defaults to `[]`. List what you need, e.g. `"types": ["node"]`.
- Removed: `baseUrl` (put prefixes in `paths`), `moduleResolution: "node"`/`"node10"` (use `bundler` or `nodenext`), `target: "es5"`, `outFile`, import `assert { }` (use `with { }`).
- TS 7's `typescript` package has no programmatic compiler API. Tools that import it need their TS 7 support.

For modern TypeScript features (`using`, `NoInfer`, `const` type params, TS 6 additions), see [references/modern-features.md](references/modern-features.md).
For compilation performance tips, see [references/performance.md](references/performance.md).
For patterns from top codebases (Zod, tRPC, Hono, TanStack), see [references/patterns-in-the-wild.md](references/patterns-in-the-wild.md).
