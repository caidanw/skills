# Fetch Patterns

Patterns for building lightweight HTTP clients. Derived from unjs/ofetch (802 lines, zero deps).

## Architecture: Factory + Late-Binding Fetch

```ts
// Late-binding: picks up polyfills applied after import
const _fetch: typeof globalThis.fetch = globalThis.fetch
  ? (...args) => globalThis.fetch(...args)
  : () => Promise.reject(new Error("fetch not supported"));

function createFetch(globalOpts: { fetch?: typeof fetch; defaults?: FetchOptions } = {}) {
  const $fetchRaw = async (request: string | Request, opts?: FetchOptions) => {
    const context = { request, options: resolveOptions(opts, globalOpts.defaults) };
    // ... lifecycle below
    return response;
  };

  const $fetch = async (request: string | Request, opts?: FetchOptions) => {
    const r = await $fetchRaw(request, opts);
    return r._data;  // just the parsed body
  };

  $fetch.raw = $fetchRaw;
  $fetch.native = globalOpts.fetch || _fetch;
  $fetch.create = (defaults = {}) => createFetch({ ...globalOpts, defaults });
  return $fetch;
}

export const ofetch = createFetch({ fetch: _fetch });
```

**Key split:** `$fetch` returns parsed body. `$fetch.raw` returns full Response with `._data` attached.

## Interceptor Hooks (as options, not .use())

```ts
interface FetchOptions extends Omit<RequestInit, "body"> {
  baseURL?: string;
  query?: Record<string, any>;
  body?: RequestInit["body"] | Record<string, any>;
  responseType?: "json" | "text" | "blob" | "arrayBuffer" | "stream";
  parseResponse?: (text: string) => any;
  retry?: number | false;
  retryDelay?: number | ((ctx: FetchContext) => number);
  retryStatusCodes?: number[];
  timeout?: number;
  ignoreResponseError?: boolean;

  onRequest?: MaybeArray<(ctx: FetchContext) => MaybePromise<void>>;
  onRequestError?: MaybeArray<(ctx: FetchContext & { error: Error }) => MaybePromise<void>>;
  onResponse?: MaybeArray<(ctx: FetchContext & { response: Response }) => MaybePromise<void>>;
  onResponseError?: MaybeArray<(ctx: FetchContext & { response: Response }) => MaybePromise<void>>;
}
```

Hooks fire sequentially (each can mutate context). Lifecycle order:

```
1. onRequest          -- can modify headers, query, body
2. fetch()            -- native call
3. onRequestError     -- only if fetch() throws (network error)
4. [body parsing]     -- auto-detect JSON/text/blob from Content-Type
5. onResponse         -- always fires for successful fetch (any status)
6. onResponseError    -- if status 400-599
```

**URL construction happens AFTER onRequest** -- hooks can modify `query`/`baseURL`.

## Smart Retry Logic

```ts
const RETRY_STATUS_CODES = new Set([408, 409, 425, 429, 500, 502, 503, 504]);
const PAYLOAD_METHODS = new Set(["PATCH", "POST", "PUT", "DELETE"]);

async function onError(ctx: FetchContext): Promise<Response> {
  // Don't retry user-initiated aborts
  const isAbort = ctx.error?.name === "AbortError" && !ctx.options.timeout;
  if (ctx.options.retry === false || isAbort) throw createFetchError(ctx);

  // Safe default: 1 retry for GET, 0 for mutations
  const retries = typeof ctx.options.retry === "number"
    ? ctx.options.retry
    : PAYLOAD_METHODS.has(ctx.options.method?.toUpperCase() || "") ? 0 : 1;

  const status = ctx.response?.status || 500; // no response = treat as 500

  if (retries > 0 && RETRY_STATUS_CODES.has(status)) {
    const delay = typeof ctx.options.retryDelay === "function"
      ? ctx.options.retryDelay(ctx) : ctx.options.retryDelay || 0;
    if (delay > 0) await new Promise(r => setTimeout(r, delay));

    // Recursive -- all hooks re-fire on retry
    return $fetchRaw(ctx.request, { ...ctx.options, retry: retries - 1 });
  }

  throw createFetchError(ctx);
}
```

Key: Retry via recursion means hooks fire again (e.g., `onRequest` adds fresh auth token).

## Auto Body Serialization

```ts
function isJSONSerializable(value: any): boolean {
  if (value === undefined) return false;
  const t = typeof value;
  if (t === "string" || t === "number" || t === "boolean" || value === null) return true;
  if (t !== "object") return false;
  if (Array.isArray(value)) return true;
  if (value.buffer) return false; // ArrayBuffer views
  if (value instanceof FormData || value instanceof URLSearchParams) return false;
  return value.constructor?.name === "Object" || typeof value.toJSON === "function";
}

// In $fetchRaw, before native fetch:
if (isJSONSerializable(body) && typeof body !== "string") {
  const ct = headers.get("content-type");
  opts.body = ct === "application/x-www-form-urlencoded"
    ? new URLSearchParams(body as Record<string, any>).toString()
    : JSON.stringify(body);
  if (!ct) headers.set("content-type", "application/json");
  if (!headers.has("accept")) headers.set("accept", "application/json");
}
```

## Auto Response Parsing

```ts
const JSON_RE = /^application\/(?:[\w!#$%&*.^`~-]*\+)?json(;.+)?$/i;

function detectResponseType(contentType = ""): string {
  if (!contentType) return "json"; // default
  const ct = contentType.split(";")[0] || "";
  if (JSON_RE.test(ct)) return "json"; // application/json, application/vnd.api+json, etc.
  if (ct === "text/event-stream") return "stream";
  if (ct.startsWith("text/")) return "text";
  return "blob";
}

// Parse based on detected type
const NULL_BODY = new Set([101, 204, 205, 304]);

if (response.body && !NULL_BODY.has(response.status) && method !== "HEAD") {
  const type = opts.parseResponse ? "json" : opts.responseType || detectResponseType(/*...*/);
  if (type === "json") {
    const text = await response.text();
    response._data = text ? (opts.parseResponse || JSON.parse)(text) : undefined;
  } else if (type === "stream") {
    response._data = response.body;
  } else {
    response._data = await response[type]();
  }
}
```

## FetchError with Lazy Getters

```ts
class FetchError extends Error {
  name = "FetchError";
  constructor(message: string, opts?: { cause: unknown }) {
    super(message, opts);
    if (opts?.cause && !this.cause) this.cause = opts.cause;
  }
}

function createFetchError(ctx: FetchContext): FetchError {
  const method = ctx.options.method || "GET";
  const url = String(ctx.request);
  const status = ctx.response ? `${ctx.response.status} ${ctx.response.statusText}` : "<no response>";
  const error = new FetchError(`[${method}] ${url}: ${status}${ctx.error ? ` ${ctx.error.message}` : ""}`);

  // Lazy getters -- live reference to context
  for (const key of ["request", "options", "response"] as const) {
    Object.defineProperty(error, key, { get: () => ctx[key] });
  }
  // Convenience aliases
  Object.defineProperty(error, "data", { get: () => ctx.response?._data });
  Object.defineProperty(error, "status", { get: () => ctx.response?.status });

  if (Error.captureStackTrace) Error.captureStackTrace(error, $fetchRaw);
  return error;
}
```

`Error.captureStackTrace` removes library internals from stack -- user sees where they called `$fetch`.

## Composable Timeouts

```ts
if (opts.timeout) {
  opts.signal = opts.signal
    ? AbortSignal.any([AbortSignal.timeout(opts.timeout), opts.signal])
    : AbortSignal.timeout(opts.timeout);
}
```

## Query String Building

```ts
function withQuery(url: string, query?: Record<string, any>): string {
  if (!query || Object.keys(query).length === 0) return url;
  const idx = url.indexOf("?");
  const params = idx >= 0 ? new URLSearchParams(url.slice(idx + 1)) : new URLSearchParams();
  const base = idx >= 0 ? url.slice(0, idx) : url;

  for (const [key, value] of Object.entries(query)) {
    if (value === undefined) { params.delete(key); continue; } // undefined = remove
    if (Array.isArray(value)) { for (const v of value) params.append(key, String(v)); continue; }
    params.set(key, typeof value === "object" ? JSON.stringify(value) : String(value));
  }
  const qs = params.toString();
  return qs ? `${base}?${qs}` : base;
}
```

- `undefined` deletes existing params (intentional API for removing keys)
- Arrays use `append` (produces `?tags=a&tags=b`)
- Objects are JSON-stringified

## Key Patterns

- **`$fetch` vs `$fetch.raw`** -- most callers want data, not Response
- **`$fetch.create(defaults)`** -- pre-configured instances (auth headers, baseURL)
- **Clean up non-standard options** -- delete `query`/`params` before passing to native fetch
- **Method uppercasing** -- normalize once, compare uppercase everywhere
- **Named function expressions** -- `async function $fetchRaw(...)` for readable stack traces
- **`MaybeArray<T>` for hooks** -- single function or array, no `.use()` registration API
