---
name: "TypeScript"
description: "Write clean, pragmatically functional TypeScript — simple, composable, soundly typed"
globs: ["*.ts", "*.tsx", "*.mts", "*.cts"]
---

# Pragmatic TypeScript

Write TypeScript that is **simple, clear, composable, and soundly typed**. Use the good parts of functional style — small functions, higher-order functions, discriminated unions, composition — without dogma. Mutate when it's simpler. Be explicit, not clever. Prioritize readability over density.

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

If you `switch` on a discriminant at runtime, your types should mirror that structure:

```ts
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "rect"; width: number; height: number }

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.radius ** 2
    case "rect": return s.width * s.height
  }
}
```

Use this for: request states, auth states, form steps, permissions, payment states, message types — anything with distinct modes.

## 6. Parse at the Boundary

Validate and parse data when it enters your system. After that, trust the types. Don't scatter validation checks through business logic.

```ts
// Parse once at the boundary
function parseUser(data: unknown): User {
  if (!isObject(data)) throw new ParseError("expected object")
  const name = parseString(data.name, "name")
  const email = parseEmail(data.email)
  const age = parseAge(data.age)
  return { name, email, age }
}

// Business logic trusts the types — no re-validation
function greetUser(user: User): string {
  return `Hello, ${user.name}!`
}
```

**Strengthen inputs, don't weaken outputs.** If a function needs a non-empty array, require `[T, ...T[]]` instead of accepting `T[]` and returning `T | undefined`.

```ts
// Prefer this — caller proves the precondition
function first<T>(list: [T, ...T[]]): T {
  return list[0]
}

// Over this — pushes uncertainty downstream
function first<T>(list: T[]): T | undefined {
  return list[0]
}
```

### Branded Types

When you can't make an illegal state structurally impossible, use branded types with constructors:

```ts
type EmailAddress = string & { readonly __brand: "EmailAddress" }
type UserId = string & { readonly __brand: "UserId" }

function EmailAddress(input: string): EmailAddress {
  if (!input.includes("@")) throw new Error(`Invalid email: ${input}`)
  return input as EmailAddress
}

function UserId(input: string): UserId {
  if (!input.trim()) throw new Error("UserId cannot be empty")
  return input as UserId
}

// Now these are distinct types — can't accidentally swap them
function sendEmail(to: EmailAddress, body: string): void { /* ... */ }
```

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

Use `interface` for object shapes (better error messages, extendable). Use `type` for unions, intersections, and computed types.

```ts
// interface for objects
interface User {
  id: UserId
  name: string
  email: EmailAddress
  status: Status
}

// type for unions and aliases
type AsyncResult<T> = AsyncState<T>
type UserInput = Omit<User, "id">
type Handler = (req: Request) => Promise<Response>
```

Use `unknown` over `any`. Narrow with type guards.

## 8. Factory Pattern Over Classes

For configurable, composable objects — use factory functions with closures instead of classes. Reserve classes for wrapping resources (DB connections, WebSocket, streams).

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

### Resolvable Values

One type for lazy/async/sync values — useful for config, subcommands, anything expensive:

```ts
type Resolvable<T> = T | Promise<T> | (() => T) | (() => Promise<T>)

async function resolve<T>(input: Resolvable<T>): Promise<T> {
  return typeof input === "function" ? (input as Function)() : input
}
```

## What NOT to Do

- **No classes unless wrapping a resource** (DB connection, WebSocket). Use factory functions + plain objects.
- **No `enum`** — use union types or `as const` objects.
- **No `namespace`** — use modules.
- **No `I` prefix on interfaces** — just name the thing.
- **No monads, functors, or applicatives** — this isn't Haskell.
- **No unnecessary abstraction** — three similar lines beats a premature `createGenericHandler`.
- **No `any`** — use `unknown` and narrow, or fix the type.
- **No barrel files with circular re-exports** — keep the dependency graph clean.
- **No npm packages for 10 lines of code** — inline tiny utils.

## Style

- `const` everywhere. `let` only for genuine reassignment.
- `interface` for object shapes, `type` for unions and computed types.
- Destructure in params when it helps: `({ id, name }: User) => ...`
- Optional chaining and nullish coalescing: `user?.address?.city ?? "Unknown"`
- `function` keyword for named, exported functions. Arrows for inline callbacks and short helpers.
- Trailing commas.
- Template literals over string concatenation.
- `as const` to preserve literal types.
- `satisfies` to validate shape while preserving inference.
