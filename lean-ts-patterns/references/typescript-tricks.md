# TypeScript Tricks

Advanced type patterns distilled from citty, consola, ofetch, defu, scule, pathe, and taze.

## 1. `const` Generic for Literal Preservation

Without `const`, TypeScript widens `{ type: "boolean" }` to `{ type: string }`, destroying
downstream conditional type narrowing.

```ts
// BAD: T is widened
function define<T extends ArgsDef>(def: T): T { return def; }

// GOOD: T preserves literal types
function define<const T extends ArgsDef>(def: T): T { return def; }

// Now this works:
define({
  args: { force: { type: "boolean" }, name: { type: "positional", required: true } },
  run({ args }) {
    args.force // boolean | undefined  (not: any)
    args.name  // string               (not: any)
  }
});
```

Source: citty's `defineCommand`.

## 2. Resolvable<T> -- Unified Sync/Async/Lazy

One type for values that may be sync, async, or lazy-loaded:

```ts
type Resolvable<T> = T | Promise<T> | (() => T) | (() => Promise<T>);

function resolveValue<T>(input: Resolvable<T>): T | Promise<T> {
  return typeof input === "function" ? (input as any)() : input;
}
```

Enables lazy subcommands via `() => import("./cmd").then(m => m.default)`.

Source: citty.

## 3. Conditional Type Chain for Discriminated Args

Match type-level logic to runtime dispatch:

```ts
type ParsedArg<T extends ArgDef> =
  T["type"] extends "positional" ? ResolveParsedType<T, string> :
  T["type"] extends "boolean" ? ResolveParsedType<T, boolean> :
  T["type"] extends "string" ? ResolveParsedType<T, string> :
  T["type"] extends "enum" ? ResolveParsedType<T, T["options"][number]> :
  never;

// default > required > optional
type ResolveParsedType<T, VT> =
  T extends { default: NonNullable<VT> } ? VT :
  T extends { required: true } ? VT :
  VT | undefined;
```

Source: citty.

## 4. Key Remapping for Alias Types

Create typed alias keys from the definition:

```ts
type ParsedArgs<T extends ArgsDef> =
  { [K in keyof T]: ParsedArg<T[K]> } &
  { [K in keyof T as T[K] extends { alias: string } ? T[K]["alias"] : never]: ParsedArg<T[K]> } &
  { [K in keyof T as T[K] extends { alias: string[] } ? T[K]["alias"][number] : never]: ParsedArg<T[K]> };
```

The `as` clause remaps keys: if `force: { alias: "f" }`, creates key `f` with same type as `force`.
`never` as key filters out entries without aliases.

Source: citty.

## 5. Enum Options to Union via `U[number]`

Convert a tuple type to a union of its elements:

```ts
type ParsedEnum<T> = T extends { type: "enum"; options: infer U }
  ? U extends any[] ? U[number] : never
  : never;

// With const generic:
// options: ["dev", "prod", "staging"] -> type is "dev" | "prod" | "staging"
```

Source: citty.

## 6. Branded Number for Autocomplete

```ts
type LogLevel = 0 | 1 | 2 | 3 | 4 | 5 | (number & {});
```

`(number & {})` means "any number" but IDE still suggests 0-5. Without it, the type collapses to
just `number` and autocomplete disappears.

Source: consola.

## 7. Response Type Mapping

Map a string literal to its corresponding return type:

```ts
interface ResponseMap {
  blob: Blob;
  text: string;
  arrayBuffer: ArrayBuffer;
  stream: ReadableStream<Uint8Array>;
}

type ResponseType = keyof ResponseMap | "json";

type MappedResponse<R extends ResponseType, T = any> =
  R extends keyof ResponseMap ? ResponseMap[R] : T;

// Usage:
function fetch<T = any, R extends ResponseType = "json">(
  url: string, opts?: { responseType?: R }
): Promise<MappedResponse<R, T>>;

// Results:
fetch<User[]>("/api/users")              // Promise<User[]>
fetch("/img.png", { responseType: "blob" }) // Promise<Blob>
fetch("/page", { responseType: "text" })    // Promise<string>
```

Source: ofetch.

## 8. MaybeArray + Intersection Narrowing for Hooks

```ts
type MaybeArray<T> = T | T[];

interface FetchContext<T = any> {
  request: string | Request;
  options: FetchOptions;
  response?: Response;
  error?: Error;
}

interface Hooks<T = any> {
  onRequest?: MaybeArray<(ctx: FetchContext<T>) => void>;
  // Intersection guarantees error is non-null in the callback:
  onRequestError?: MaybeArray<(ctx: FetchContext<T> & { error: Error }) => void>;
  // Intersection guarantees response is non-null:
  onResponse?: MaybeArray<(ctx: FetchContext<T> & { response: Response }) => void>;
}
```

Source: ofetch.

## 9. Declaration Merging: Class + Interface

Add typed properties to a class that are set dynamically:

```ts
class FetchError<T = any> extends Error {
  constructor(message: string, opts?: { cause: unknown }) {
    super(message, opts);
    this.name = "FetchError";
  }
}

// Declaration merge adds interface properties to the class type
interface FetchError<T = any> {
  request?: string | Request;
  response?: Response & { _data?: T };
  data?: T;
  status?: number;
  statusCode?: number; // alias
}
```

The actual properties are added via `Object.defineProperty` at runtime. TypeScript sees them
through the declaration merge.

Source: ofetch, consola.

## 10. Recursive Type Merging (defu)

```ts
type Merge<A, B> =
  A extends Record<string, any>
    ? B extends Record<string, any>
      ? MergeObjects<A, B>
      : A
    : A | B;

type MergeObjects<A, B> =
  Omit<A, keyof A & keyof B> &         // A-only keys
  Omit<B, keyof A & keyof B> &         // B-only keys
  {
    [K in keyof A & keyof B]:           // shared keys
      A[K] extends null | undefined
        ? B[K]                           // A is null -> use B
        : B[K] extends null | undefined
          ? A[K]                         // B is null -> use A
          : Merge<A[K], B[K]>;          // both present -> recurse
  };

// Variadic: Defu<Source, [Default1, Default2, ...]>
type Defu<S, D extends any[]> =
  D extends [infer F, ...infer Rest]
    ? Rest extends any[]
      ? Defu<MergeObjects<S, F>, Rest>
      : MergeObjects<S, F>
    : S;
```

Source: defu.

## 11. Type-Level String Case Conversion

Runtime `splitByCase` mirrored at the type level:

```ts
type IsUpper<S extends string> = S extends Uppercase<S> ? true : false;
type IsLower<S extends string> = S extends Lowercase<S> ? true : false;

type SplitByCase<T extends string> = /* recursive conditional type */;

type KebabCase<T extends string> = JoinLowercase<SplitByCase<T>, "-">;
type PascalCase<T extends string> = CapitalizeAll<SplitByCase<T>>;
type CamelCase<T extends string> = Uncapitalize<PascalCase<T>>;

// Compile-time results:
type A = KebabCase<"FooBarBaz">;  // "foo-bar-baz"
type B = CamelCase<"foo-bar">;    // "fooBar"
type C = PascalCase<"foo_bar">;   // "FooBar"
```

Source: scule.

## 12. `satisfies` for Validation Without Widening

```ts
const parseOptions = {
  boolean: [] as string[],
  string: [] as string[],
  alias: {} as Record<string, string[]>,
  default: {} as Record<string, boolean | string>,
} satisfies ParseOptions;
```

Verifies the object matches `ParseOptions` without widening its type. Preserves concrete
array types for later mutation.

Source: citty.

## 13. `as const satisfies` for Narrowed Validated Arrays

```ts
const allDepsFields = [
  "dependencies",
  "devDependencies",
  "peerDependencies",
  "optionalDependencies",
] as const satisfies readonly DepType[];
```

Array is both narrowly typed (literal tuple) AND validated against `DepType` union.

Source: taze.

## 14. Template Literal Types for Config

```ts
type SortKey = "time" | "diff" | "name";
type SortOrder = "asc" | "desc";
type SortOption = `${SortKey}-${SortOrder}`;
// = "time-asc" | "time-desc" | "diff-asc" | "diff-desc" | "name-asc" | "name-desc"
```

Source: taze.

## 15. Omit for Discriminated Arg Variants

Remove inapplicable fields from each variant:

```ts
interface BaseArgDef<T extends string, V> {
  type: T;
  description?: string;
  required?: boolean;
  default?: V;
  alias?: string | string[];
  options?: string[];
}

type BooleanArgDef = Omit<BaseArgDef<"boolean", boolean>, "options">;
type StringArgDef = Omit<BaseArgDef<"string", string>, "options">;
type EnumArgDef = BaseArgDef<"enum", string>; // keeps options
type PositionalArgDef = Omit<BaseArgDef<"positional", string>, "alias" | "options">;

type ArgDef = BooleanArgDef | StringArgDef | EnumArgDef | PositionalArgDef;
```

Source: citty.

## 16. Module Augmentation for Extensibility

Allow consumers to add custom properties:

```ts
// Library:
export interface FetchOptions { /* ... */ }

// Consumer:
declare module "my-fetch" {
  interface FetchOptions { requiresAuth?: boolean; }
}
```

Works because `FetchOptions` is an `interface` (not `type`), which allows declaration merging.

Source: ofetch.

## 17. Proxy for Fallback Property Access

```ts
const parsed = new Proxy(values, {
  get(target, prop: string) {
    return target[prop] ?? target[camelCase(prop)] ?? target[kebabCase(prop)];
  },
});
```

Access `args.workDir` or `args["work-dir"]` -- both resolve regardless of input form.

Source: citty.

## Key Principles

- **Types should be as smart as the runtime** -- if you switch on a discriminant, type it
- **`const` generic is almost always what you want** for definition objects
- **Intersection narrowing** (`& { error: Error }`) is cleaner than optional + assertion
- **Identity functions** (`return def`) exist purely for type inference
- **`(number & {})` preserves autocomplete** for numeric unions
- **Declaration merging** bridges dynamic runtime properties and static types
- **`satisfies`** validates without widening -- use it for mutable config objects
