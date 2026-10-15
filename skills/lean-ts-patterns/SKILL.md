---
name: lean-ts-patterns
description: >-
  Build lightweight TypeScript tools and libraries with few or no dependencies. Use when
  building a CLI, library, or utility; when deciding whether to add a dependency; or when
  replacing a package with a Node, Bun, or browser built-in. Covers the built-ins that replace
  common packages and unjs-style library design (one core primitive, factories, smart defaults).
  Triggers on: "build a CLI", "zero-dep", "remove dependencies", "do I need a library for",
  "fetch wrapper", "write a logger", "lightweight", "inline utility".
---

# Lean TypeScript

Ship less code you did not write, and less code you have to maintain. Library-design patterns come from studying unjs (citty, consola, ofetch, defu, scule, pathe) and antfu/taze.

## Decision Order

1. **Platform built-in.** Check the table below first.
2. **A dependency the project already has.** Use it the way the codebase already does.
3. **Inline it.** Only when it is under ~50 lines, you understand every line, and you add a test.
4. **A small, zero-dependency package.**

Do not inline crypto, auth, sanitizers, parsers for untrusted or quirky formats (YAML, CSV
quoting, HTML), date and timezone math, or semver ranges. A maintained library beats your
edge-case bugs there.

## Built-ins That Replace Packages

Assumes Node 22+ (current LTS lines: 22, 24). Bun and Deno implement most `node:` APIs; check
before relying on the newest ones.

| Need | Built-in | Instead of |
|---|---|---|
| CLI args | `util.parseArgs` (`allowNegative` for `--no-x`, Node 22.4+) | commander, yargs, minimist |
| Terminal colors | `util.styleText` (honors TTY, `NO_COLOR`, `FORCE_COLOR`) | chalk, picocolors |
| Strip ANSI | `util.stripVTControlCharacters` | strip-ansi |
| HTTP | `fetch` + `AbortSignal.timeout()` / `AbortSignal.any()` | axios, node-fetch |
| `.env` files | `node --env-file=.env`, `process.loadEnvFile()`, `util.parseEnv()` | dotenv |
| Globbing | `fs.promises.glob` (stable in Node 24, 22.17) | glob, fast-glob |
| Run `.ts` directly | `node script.ts` (type stripping; erasable syntax only) | ts-node, tsx for simple scripts |
| Test runner | `node:test` + `node:assert/strict` | jest, mocha for libraries and CLIs |
| Watch mode | `node --watch` | nodemon |
| Deep clone | `structuredClone()` | lodash.clonedeep |
| Deep equality | `util.isDeepStrictEqual()` | fast-deep-equal |
| Group by | `Object.groupBy()`, `Map.groupBy()` | lodash.groupby |
| Copying array ops | `toSorted`, `toReversed`, `toSpliced`, `with` | spread-then-mutate |
| Set algebra | `union`, `intersection`, `difference` (ES2025) | lodash set helpers |
| Lazy iteration | Iterator helpers: `.map`, `.filter`, `.take`, `.toArray` (ES2025) | itertools packages |
| Deferred promise | `Promise.withResolvers()` | p-defer |
| UUID v4 | `crypto.randomUUID()` | uuid |
| Escape for RegExp | `RegExp.escape()` (ES2025) | escape-string-regexp |

## Library Design Patterns

- **One core primitive, thin wrappers.** scule's `splitByCase()` powers every case converter; pathe's `normalizeWindowsPath()` sits under every path function; consola's levels all call one log function. Fix a bug once, every wrapper gets it.
- **Factory with `.create(defaults)`.** `createFetch()`, `createConsola()`: a closure captures config and returns a callable instance that can spawn preconfigured children. See the `typescript-best-practices` skill for factories versus classes.
- **`define*` identity helpers.** `defineCommand`, `defineConfig` return their argument; a `const` type parameter keeps literal types. See the `typescript-best-practices` skill.
- **Smart defaults, explicit escape hatches.** ofetch retries GET once and mutations zero times; consola picks a fancy reporter in a TTY and plain output in CI; defu treats `null`/`undefined` as "not set".
- **Hooks as options.** `{ onRequest, onResponse, onError }` beat a `.use()` middleware chain for small libraries.
- **Lazy values.** `Resolvable<T> = T | Promise<T> | (() => T | Promise<T>)` lets subcommands and config load via dynamic `import()` only when used.
- **Types mirror runtime.** If runtime code switches on `arg.type`, the types branch on the same discriminant.
- **Small public surface.** One entry point; `_`-prefixed internal files are never exported.

## Snippets

Tested on Node 26.

### CLI args and colors

```ts
import { parseArgs, styleText } from "node:util";

const { values, positionals } = parseArgs({
  allowPositionals: true,
  allowNegative: true, // --no-color sets color: false
  options: {
    out: { type: "string", short: "o", default: "dist" },
    color: { type: "boolean", default: true },
    verbose: { type: "boolean", short: "v", multiple: true }, // -vv → [true, true]
  },
});

// Plain text when stderr is not a TTY or NO_COLOR is set
console.error(styleText(["bold", "red"], "error:", { stream: process.stderr }), "build failed");
```

### fetch with timeout and retries

```ts
const RETRYABLE = new Set([408, 425, 429, 500, 502, 503, 504]);

class HttpError extends Error {
  readonly response: Response;
  constructor(response: Response) {
    super(`${response.status} ${response.statusText}: ${response.url}`);
    this.response = response;
  }
}

async function fetchJson<T>(
  url: string | URL,
  { timeout = 10_000, retries, ...init }: RequestInit & { timeout?: number; retries?: number } = {},
): Promise<T> {
  // Only retry idempotent requests unless the caller opts in.
  const maxRetries = retries ?? (!init.method || init.method === "GET" ? 2 : 0);
  for (let attempt = 0; ; attempt++) {
    const timeoutSignal = AbortSignal.timeout(timeout);
    const signal = init.signal ? AbortSignal.any([init.signal, timeoutSignal]) : timeoutSignal;
    try {
      const res = await fetch(url, { ...init, signal });
      if (res.ok) return (await res.json()) as T;
      throw new HttpError(res);
    } catch (err) {
      const retryable = err instanceof HttpError
        ? RETRYABLE.has(err.response.status)
        : !init.signal?.aborted; // network error or our timeout, not a caller abort
      if (!retryable || attempt >= maxRetries) throw err;
    }
    await new Promise((resolve) => setTimeout(resolve, 250 * 2 ** attempt));
  }
}
```

## References

| Need | Reference |
|---|---|
| Typed CLI args, lazy subcommands, help text, `runMain` | [cli-patterns.md](references/cli-patterns.md) |
| Fetch factory, interceptor hooks, body and response handling | [fetch-patterns.md](references/fetch-patterns.md) |
| Logger with levels, reporters, throttling, scoped tags | [logging-patterns.md](references/logging-patterns.md) |
| Deep defaults (defu), case conversion (scule), paths (pathe), shared queues, file cache | [data-utils.md](references/data-utils.md) |
| Type tricks from these libraries (`const` generics, key remapping, module augmentation) | [typescript-tricks.md](references/typescript-tricks.md) |

## Anti-Patterns

- Adding a package for something in the table above.
- Inlining security, parsing, or date code to avoid a dependency.
- Copy-pasting a utility without a test.
- Adding "flexibility" or options nobody asked for.
- A class hierarchy for configuration when a factory closure does the job.
- Exporting internals from a barrel file; keep the public surface to one entry.
