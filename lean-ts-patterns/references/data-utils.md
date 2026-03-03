# Data Utility Patterns

Patterns for lightweight data manipulation. Derived from unjs/defu, unjs/scule, unjs/pathe.

## Deep Defaults (defu pattern)

The key difference from `Object.assign` or spread: **defaults fill in**, they don't overwrite.
`null`/`undefined` in the source = "not set", let defaults provide the value.

```ts
function isPlainObject(value: unknown): boolean {
  if (value === null || typeof value !== "object") return false;
  const proto = Object.getPrototypeOf(value);
  if (proto !== null && proto !== Object.prototype
      && Object.getPrototypeOf(proto) !== null) return false;
  if (Symbol.iterator in value) return false;
  return true;
}

function defu<T>(source: T, ...defaults: any[]): T {
  return defaults.reduce((acc, def) => _merge(acc, def), source) as T;
}

function _merge(source: any, defaults: any, namespace = ""): any {
  if (!isPlainObject(defaults)) return source;
  const result = { ...defaults }; // start with defaults

  for (const key in source) {
    if (key === "__proto__" || key === "constructor") continue; // prototype pollution guard
    const val = source[key];
    if (val === null || val === undefined) continue; // null = "not set"

    if (Array.isArray(val) && Array.isArray(result[key])) {
      result[key] = [...val, ...result[key]]; // arrays: concatenate
    } else if (isPlainObject(val) && isPlainObject(result[key])) {
      result[key] = _merge(val, result[key], `${namespace}${key}.`); // recurse
    } else {
      result[key] = val; // source wins
    }
  }
  return result;
}
```

### Custom Merger Factory

```ts
type Merger = (obj: any, key: string, value: any, namespace: string) => boolean | void;

function createDefu(merger?: Merger) {
  return (...args: any[]) => args.reduce((acc, def) => _merge(acc, def, "", merger), {});
}

// defuFn: function values get called with the default as argument
const defuFn = createDefu((obj, key, currentValue) => {
  if (obj[key] !== undefined && typeof currentValue === "function") {
    obj[key] = currentValue(obj[key]);
    return true; // "I handled this"
  }
});

// Usage:
defuFn(
  { ignore: (val) => val.filter(i => i !== "dist") },
  { ignore: ["node_modules", "dist"] }
)
// => { ignore: ["node_modules"] }
```

The merger receives `namespace` (dotted path like `"foo.bar."`) for context-aware merging.

---

## String Case Conversion (scule pattern)

### Core: splitByCase

Everything builds on one function that splits strings at case boundaries and separators:

```ts
const SPLITTERS = ["-", "_", "/", "."];

function isUppercase(char: string): boolean | undefined {
  if (/\d/.test(char)) return undefined; // digits are neutral
  return char !== char.toLowerCase();
}

function splitByCase(str: string, separators = SPLITTERS): string[] {
  const parts: string[] = [];
  let buff = "";
  let prevUpper: boolean | undefined;
  let prevSplitter: boolean | undefined;

  for (const char of str) {
    const isSplitter = separators.includes(char);
    if (isSplitter) { parts.push(buff); buff = ""; prevUpper = undefined; prevSplitter = true; continue; }

    const isUpper = isUppercase(char);

    if (prevSplitter === false) {
      // Rising edge: "fooBar" -> split before "B"
      if (prevUpper === false && isUpper === true) {
        parts.push(buff); buff = char; prevUpper = isUpper; continue;
      }
      // Falling edge: "FOOBar" -> ["FOO", "Bar"]
      if (prevUpper === true && isUpper === false && buff.length > 1) {
        const last = buff.at(-1)!;
        parts.push(buff.slice(0, -1)); buff = last + char; prevUpper = isUpper; continue;
      }
    }

    buff += char;
    prevUpper = isUpper;
    prevSplitter = isSplitter;
  }
  parts.push(buff);
  return parts.filter(Boolean);
}
```

### All case functions compose on splitByCase

```ts
const upperFirst = (s: string) => s[0]?.toUpperCase() + s.slice(1);

function pascalCase(str: string): string {
  return splitByCase(str).map(p => upperFirst(p)).join("");
}

function camelCase(str: string): string {
  const p = pascalCase(str);
  return p[0]?.toLowerCase() + p.slice(1);
}

function kebabCase(str: string, joiner = "-"): string {
  return splitByCase(str).map(p => p.toLowerCase()).join(joiner);
}

function snakeCase(str: string): string { return kebabCase(str, "_"); }
function flatCase(str: string): string { return kebabCase(str, ""); }

function trainCase(str: string): string {
  return splitByCase(str).map(p => upperFirst(p)).join("-");
}

function titleCase(str: string): string {
  const exceptions = /^(a|an|and|as|at|but|by|for|if|in|is|nor|of|on|or|the|to|with)$/i;
  return splitByCase(str).map((p, i) =>
    i > 0 && exceptions.test(p) ? p.toLowerCase() : upperFirst(p)
  ).join(" ");
}
```

---

## Path Normalization (pathe pattern)

### Core: Always POSIX, One Normalizer

```ts
const DRIVE_RE = /^[A-Za-z]:\//;

function normalizeWindowsPath(input = ""): string {
  if (!input) return input;
  return input.replace(/\\/g, "/").replace(DRIVE_RE, r => r.toUpperCase());
}
```

Every path function calls this on input first. Accepts Windows paths on any platform.

### Smart join Without Double Slashes

```ts
function join(...segments: string[]): string {
  let path = "";
  for (const seg of segments) {
    if (!seg) continue;
    const s = normalizeWindowsPath(seg);
    if (!path) { path = s; continue; }
    const trailing = path.endsWith("/");
    const leading = s.startsWith("/");
    if (trailing && leading) path += s.slice(1);
    else if (!trailing && !leading) path += "/" + s;
    else path += s;
  }
  return normalize(path);
}
```

### Alias Resolution with Symbol-Based Idempotency

```ts
const NORMALIZED = Symbol.for("normalizedAlias");

function normalizeAliases(aliases: Record<string, string>): Record<string, string> {
  if ((aliases as any)[NORMALIZED]) return aliases; // already done

  // Sort: more specific aliases first (deeper paths)
  const sorted = Object.fromEntries(
    Object.entries(aliases).sort(([a], [b]) => b.split("/").length - a.split("/").length)
  );

  // Resolve alias chains: if alias A -> B and B -> C, resolve A -> C
  for (const key in sorted) {
    for (const alias in sorted) {
      if (alias === key || key.startsWith(alias)) continue;
      if (sorted[key]?.startsWith(alias) && "/\\".includes(sorted[key][alias.length] || "")) {
        sorted[key] = sorted[alias] + sorted[key].slice(alias.length);
      }
    }
  }

  Object.defineProperty(sorted, NORMALIZED, { value: true, enumerable: false });
  return sorted;
}

function resolveAlias(path: string, aliases: Record<string, string>): string {
  const normalized = normalizeAliases(aliases);
  for (const [alias, target] of Object.entries(normalized)) {
    if (path === alias || (path.startsWith(alias) && "/\\".includes(path[alias.length] || ""))) {
      return target + path.slice(alias.length);
    }
  }
  return path;
}
```

### filename (handles dotfiles correctly)

```ts
function filename(path: string): string | undefined {
  const base = path.split(/[/\\]/).pop();
  if (!base) return undefined;
  const dotIdx = base.lastIndexOf(".");
  if (dotIdx <= 0) return base; // <= 0: dotfiles like ".gitignore" keep their name
  return base.slice(0, dotIdx);
}
```

---

## Concurrency: AsyncLocalStorage + Queue

From taze -- share a concurrency limit across parallel work without passing it everywhere:

```ts
import { AsyncLocalStorage } from "node:async_hooks";

const queueContext = new AsyncLocalStorage<Queue>();

// Orchestrator creates the queue
async function checkAll(packages: Package[], concurrency = 10) {
  const queue = createQueue(concurrency);
  await queueContext.run(queue, () =>
    Promise.all(packages.map(pkg => resolveDeps(pkg)))
  );
}

// Worker retrieves it (or creates a fallback for standalone use)
async function resolveDeps(pkg: Package) {
  const queue = queueContext.getStore() || createQueue(10);
  return Promise.all(
    pkg.deps.map(dep => queue.add(() => resolveFromRegistry(dep)))
  );
}
```

---

## File-Based Response Cache

From taze -- cache expensive API responses in temp directory:

```ts
import { existsSync, lstatSync } from "node:fs";
import { resolve } from "node:path";
import { tmpdir } from "node:os";
import * as fs from "node:fs/promises";

const CACHE_DIR = resolve(tmpdir(), "my-tool");
const CACHE_PATH = resolve(CACHE_DIR, "cache.json");
const CACHE_TTL = 30 * 60_000; // 30 minutes

let cache: Record<string, { time: number; data: any }> = {};

async function loadCache() {
  if (existsSync(CACHE_PATH) && Date.now() - lstatSync(CACHE_PATH).mtimeMs < CACHE_TTL) {
    cache = JSON.parse(await fs.readFile(CACHE_PATH, "utf-8"));
  }
}

async function saveCache() {
  await fs.mkdir(CACHE_DIR, { recursive: true });
  await fs.writeFile(CACHE_PATH, JSON.stringify(cache), "utf-8");
}

async function cached<T>(key: string, fn: () => Promise<T>): Promise<T> {
  if (cache[key] && Date.now() - cache[key].time < CACHE_TTL) return cache[key].data;
  const data = await fn();
  cache[key] = { time: Date.now(), data };
  return data;
}
```

---

## Key Patterns

- **Prototype pollution guard**: Always skip `__proto__` and `constructor` in object iteration
- **`null`/`undefined` = "not set"**: Let defaults fill in, don't overwrite with nothing
- **One primitive, many wrappers**: `splitByCase` -> all case functions
- **Symbol markers for idempotency**: Prevent double-processing with non-enumerable symbol properties
- **Digits are caseless**: In `splitByCase`, digits don't trigger case transitions
- **`<= 0` for dotfiles**: `lastIndexOf(".")` returns 0 for `.gitignore`, treat as no extension
- **Indent preservation**: Use `detect-indent` when rewriting JSON/YAML files
