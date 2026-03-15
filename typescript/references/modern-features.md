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
