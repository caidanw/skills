# TypeScript Compilation Performance

Practical tips for keeping `tsc` fast. Drawn from the [TypeScript Performance Wiki](https://github.com/microsoft/TypeScript/wiki/Performance) and real-world experience.

## Writing Fast-to-Compile Code

### Prefer `interface extends` Over `&` Intersections

Interfaces create flat object types that TypeScript can cache by name. Intersections must be recomputed each time.

```ts
// Faster — cached, flat type
interface User extends BaseEntity {
  name: string
  email: string
}

// Slower — recomputed on each check
type User = BaseEntity & {
  name: string
  email: string
}
```

**Rule of thumb:** Use `type` for most things (unions, aliases, computed types), but when composing object types via inheritance, use `interface extends`.

### Add Explicit Return Types on Exports

When TypeScript infers a return type, it must compute the full type and emit it into `.d.ts` files. If the type references things from other modules, it generates `import("./path").Type` references — expensive to compute and print.

```ts
// Slower — compiler must infer and emit the return type
export function getUser(id: string) {
  return db.users.findUnique({ where: { id } })
}

// Faster — compiler knows the type immediately
export function getUser(id: string): Promise<User | null> {
  return db.users.findUnique({ where: { id } })
}
```

### Name Complex Types

Anonymous complex types (inline conditional types, deep mapped types) get recomputed every time they're compared. Extract them to named type aliases so the compiler can cache them.

```ts
// Slower — recomputed every time foo is called or compared
interface SomeType<T> {
  foo<U>(x: U):
    U extends TypeA<T> ? ProcessTypeA<U, T> :
    U extends TypeB<T> ? ProcessTypeB<U, T> : U
}

// Faster — the alias is cached
type FooResult<U, T> =
  U extends TypeA<T> ? ProcessTypeA<U, T> :
  U extends TypeB<T> ? ProcessTypeB<U, T> : U

interface SomeType<T> {
  foo<U>(x: U): FooResult<U, T>
}
```

### Watch Out for Large Unions

Unions with more than ~12 members cause quadratic comparison behavior. Each argument must be checked against every member. If you're modeling something like DOM element types, prefer a base type with `extends`:

```ts
// Quadratic — avoid for large sets
type Element = DivElement | SpanElement | ImgElement | /* 50 more... */

// Linear — prefer for large sets
interface HtmlElement { tag: string; /* common props */ }
interface DivElement extends HtmlElement { tag: "div" }
interface ImgElement extends HtmlElement { tag: "img"; src: string }

function render(el: HtmlElement) { /* ... */ }
```

## tsconfig Performance Settings

```jsonc
{
  "compilerOptions": {
    // Save state between builds — faster incremental compiles
    "incremental": true,

    // Skip type-checking .d.ts files from node_modules
    "skipLibCheck": true,

    // Enable faster variance checks (on by default with --strict)
    "strictFunctionTypes": true,

    // Only include @types packages you actually need
    "types": ["node"],

    // Modern module resolution for bundlers — faster resolution
    "moduleResolution": "bundler"
  },
  "include": ["src"],
  "exclude": ["**/node_modules", "**/.*"]
}
```

### Key Settings Explained

| Setting | What it does | Impact |
|---------|-------------|--------|
| `incremental` | Saves `.tsbuildinfo` to recheck only changed files | Large projects: 2-10x faster rebuilds |
| `skipLibCheck` | Skips checking `.d.ts` in `node_modules` | Saves seconds on every build |
| `types: []` | Only includes explicitly listed `@types` packages | Prevents loading Jasmine/Mocha types you don't use |
| `isolatedDeclarations` | Requires explicit annotations on exports | Enables parallel `.d.ts` generation |

## Project References for Monorepos

Split large codebases into projects that reference each other. Each project compiles independently with its own `.tsbuildinfo`.

```
              ┌──────────┐
              │  Shared  │
              └────┬─────┘
              ┌────┴─────┐
         ┌────┴──┐   ┌───┴───┐
         │Client │   │Server │
         └───────┘   └───────┘
```

**Guidelines:**
- Aim for 5-20 projects (fewer → editor slowdowns, more → excessive overhead)
- Group files edited together into the same project
- Separate test code from production code
- Use `--build` mode for parallel builds

## Diagnosing Slow Builds

```bash
# See where time is spent
tsc --extendedDiagnostics -p tsconfig.json

# Check what files are included
tsc --listFilesOnly

# Explain why a file is included
tsc --explainFiles > explanations.txt

# Generate a performance trace (view at about://tracing in Chrome)
tsc --generateTrace ./trace-output
```

**Common culprits:**
- `include` is too broad (pulling in `node_modules` or test files)
- Missing `exclude` for `**/node_modules`
- Barrel files (`index.ts`) creating massive module graphs
- Complex conditional types in hot paths
- No `incremental` flag
