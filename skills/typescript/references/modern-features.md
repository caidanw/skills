# Modern TypeScript Features (5.0+)

Quick reference for TypeScript features that change how you write code day-to-day.

## `using` and Explicit Resource Management (TS 5.2+)

Automatic cleanup when a variable goes out of scope. Use for file handles, DB connections, locks, timers — anything that needs disposal.

```ts
function readConfig(path: string): Config {
  using file = openFile(path) // file[Symbol.dispose]() called at block end
  return JSON.parse(file.readAll())
}

// Async version
async function withTransaction<T>(fn: (tx: Transaction) => Promise<T>): Promise<T> {
  await using tx = await db.beginTransaction()
  const result = await fn(tx)
  await tx.commit()
  return result
} // tx[Symbol.asyncDispose]() called if commit wasn't reached
```

To make a class disposable:

```ts
class TempFile implements Disposable {
  #path: string

  constructor(prefix: string) {
    this.#path = `${tmpdir()}/${prefix}-${randomUUID()}`
    writeFileSync(this.#path, "")
  }

  get path() { return this.#path }

  [Symbol.dispose]() {
    rmSync(this.#path, { force: true })
  }
}

// Usage
{
  using tmp = new TempFile("upload")
  await processFile(tmp.path)
} // file deleted automatically
```

**When to use:** Any time you'd write a try/finally to clean up a resource. `using` makes it impossible to forget cleanup.

**Requires:** `"lib": ["esnext"]` or `"lib": ["esnext.disposable"]` in tsconfig.

## `NoInfer<T>` Utility Type (TS 5.4+)

Prevents TypeScript from inferring a type parameter from a specific position. Useful when you want one argument to constrain the type, not both.

```ts
// Without NoInfer — "blue" widens the type, no error
function createLight<C extends string>(colors: C[], defaultColor: C) {}
createLight(["red", "yellow", "green"], "blue") // no error! C inferred as "red" | "yellow" | "green" | "blue"

// With NoInfer — default must be one of the provided colors
function createLight<C extends string>(colors: C[], defaultColor: NoInfer<C>) {}
createLight(["red", "yellow", "green"], "blue") // Error! "blue" not in "red" | "yellow" | "green"
```

**When to use:** Generic functions where one argument should be the "source of truth" for the type parameter, and other arguments should be constrained by it.

## `const` Type Parameters (TS 5.0+)

Forces const-like inference — preserves literal types instead of widening to `string[]`, `number[]`, etc.

```ts
// Without const — types widen
function getNames<T extends { names: readonly string[] }>(arg: T): T["names"] {
  return arg.names
}
const names = getNames({ names: ["Alice", "Bob"] })
// Type: readonly string[]

// With const — literal types preserved
function getNames<const T extends { names: readonly string[] }>(arg: T): T["names"] {
  return arg.names
}
const names = getNames({ names: ["Alice", "Bob"] })
// Type: readonly ["Alice", "Bob"]
```

**When to use:** Config objects, route definitions, builder patterns — anywhere you need the exact literal values at the type level.

## `satisfies` Operator (TS 4.9+)

Type-checks a value against a type without widening. You get both validation AND preserved inference.

```ts
// as const + satisfies = validated literal types
const routes = {
  home: "/",
  about: "/about",
  user: "/user/:id",
} as const satisfies Record<string, string>

// Type is the full literal: { readonly home: "/"; readonly about: "/about"; ... }
// But if you typo a value (e.g., number instead of string), you get an error
```

Common patterns:

```ts
// Validate config shape while keeping literals
const config = {
  port: 3000,
  host: "localhost",
  debug: true,
} satisfies Record<string, string | number | boolean>

// Validate map completeness
type Status = "idle" | "loading" | "error" | "success"

const statusLabels = {
  idle: "Not started",
  loading: "In progress",
  error: "Failed",
  success: "Complete",
} satisfies Record<Status, string>
// Adding a new Status variant causes a compile error here
```

## `--erasableSyntaxOnly` (TS 5.8+)

Marks enums, namespaces, and class parameter properties as errors. These are "non-erasable" — they can't be removed by simply deleting type annotations.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "erasableSyntaxOnly": true
  }
}
```

**Why use it:**
- Node's native TypeScript support (type stripping) only handles erasable syntax
- Aligns with the TC39 "types as comments" proposal
- Forces you toward union types, modules, and explicit class fields — which are better patterns anyway

## Type Narrowing Patterns

TypeScript narrows types through control flow analysis. These patterns are essential for working with `unknown`, union types, and nullable values.

### Type Predicates (`is`)

Custom narrowing functions that tell TypeScript which type a value is:

```ts
function isNonNull<T>(val: T | null | undefined): val is T {
  return val != null
}

// Narrows arrays: (string | null)[] → string[]
const names = rawNames.filter(isNonNull)

// Narrows in if blocks
function processEvent(event: MouseEvent | KeyboardEvent) {
  if (isKeyboardEvent(event)) {
    console.log(event.key) // typed as KeyboardEvent
  }
}

function isKeyboardEvent(e: Event): e is KeyboardEvent {
  return "key" in e
}
```

### Assertion Functions (`asserts`)

Narrow by throwing — useful for validation at boundaries:

```ts
function assertDefined<T>(val: T | undefined, msg: string): asserts val is T {
  if (val === undefined) throw new Error(msg)
}

function assertString(val: unknown): asserts val is string {
  if (typeof val !== "string") throw new TypeError(`Expected string, got ${typeof val}`)
}

// After the assertion, TypeScript knows the type
const env = process.env.DATABASE_URL
assertDefined(env, "DATABASE_URL is required")
// env is now `string`, not `string | undefined`
```

### `in` Operator Narrowing

Check for property existence to narrow union types:

```ts
type Fish = { swim: () => void }
type Bird = { fly: () => void }

function move(animal: Fish | Bird) {
  if ("swim" in animal) {
    animal.swim() // narrowed to Fish
  } else {
    animal.fly()  // narrowed to Bird
  }
}
```

### `Error.cause` for Error Chaining (ES2022)

Preserve the original error when wrapping with a higher-level message:

```ts
async function loadUser(id: string): Promise<User> {
  try {
    const res = await fetch(`/api/users/${id}`)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return await res.json()
  } catch (err) {
    throw new Error(`Failed to load user ${id}`, { cause: err })
  }
}

// Debugging: the full chain is accessible
try {
  await loadUser("123")
} catch (err) {
  console.error(err)       // "Failed to load user 123"
  console.error(err.cause) // "HTTP 404" (or network error, etc.)
}
```

## Import Attributes (TS 5.3+)

Replaces the deprecated `assert` syntax for imports:

```ts
// Old (deprecated)
import data from "./data.json" assert { type: "json" }

// New
import data from "./data.json" with { type: "json" }
```

## Isolated Declarations (TS 5.5+)

Requires explicit return types and type annotations on exports. Enables fast parallel `.d.ts` generation by tools other than `tsc`.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "isolatedDeclarations": true
  }
}
```

**When to use:** Large monorepos where build speed matters. Pairs well with explicit return types on exported functions (which you should be writing anyway).
