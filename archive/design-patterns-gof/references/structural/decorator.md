# Decorator

**Category:** Structural · **Modern relevance:** Ubiquitous (middleware, wrappers)

## Intent

Attach new behavior to an object by wrapping it in another object that shares its interface and
delegates to it — stackably, at runtime.

## Problem

Behavior combinations explode under inheritance. If you need notifications that are
email + SMS + encrypted + throttled, the subclass matrix is unmanageable. Decorator lets you
compose behaviors at runtime like Lego.

## Structure

- **Component** — interface.
- **ConcreteComponent** — the base object.
- **BaseDecorator** — implements Component, holds a wrapped Component.
- **ConcreteDecorator** — overrides methods to add behavior before/after delegating.

## Applicability

- Behavior must be added/removed dynamically.
- You need many orthogonal combinations.
- You can't subclass (final/sealed classes, or the class is chosen at runtime).

## Consequences

**Pros:** Runtime composition. SRP (each decorator does one thing). Avoids subclass explosion.

**Cons:** Order matters and is easy to get wrong. Hard to remove a specific wrapper mid-stack.
Stack traces through 8 wrappers are painful. Identity checks (`instanceof`) break.

## When NOT to use

- One or two always-on behaviors — just put them in the base class.
- Behaviors interact non-trivially — Decorator assumes composition is commutative-ish, which it
  rarely is for auth + logging + caching.
- A middleware *list* would be clearer than nested wrappers.

## Modern relevance

Ubiquitous under different names. Express/Koa middleware, Redux middleware, Python decorators
(`@cache`, `@retry`), Java Servlet filters, ASP.NET middleware, gRPC interceptors, HTTP client
middleware. `app.use(logger); app.use(auth);` is stacked decorators.

## Code sketch (TypeScript)

```ts
type Handler = (req: Request) => Promise<Response>

const withLogging = (next: Handler): Handler => async (req) => {
  console.log("→", req.url)
  const res = await next(req)
  console.log("←", res.status)
  return res
}

const withAuth = (next: Handler): Handler => async (req) => {
  if (!req.headers.get("authorization")) return new Response("no", { status: 401 })
  return next(req)
}

const base: Handler = async () => new Response("ok")
const app = withLogging(withAuth(base))  // stack
```

## Real-world uses

- Express/Koa/Hono middleware
- Java `BufferedInputStream(new FileInputStream(...))`
- Python `functools.lru_cache`, `@retry`
- React higher-order components (historical)
- RxJS `pipe()` composition

## Distinguishing from neighbors

- **vs. Proxy** — Both wrap the same interface. Decorator *adds* orthogonal behavior, composed by
  the client. Proxy *controls access* (lazy, auth, caching of the object itself) and typically
  owns the service's lifecycle. One Proxy, many Decorators.
- **vs. Adapter** — Decorator preserves the interface; Adapter changes it.
- **vs. Chain of Responsibility** — CoR may *stop* propagation; Decorator always delegates.
- **vs. Composite** — Decorator wraps one; Composite aggregates many.

## Rule of thumb

Decorator chains are usually better expressed as an explicit middleware **list** (array you can
inspect, reorder, and log) than as 6 nested constructors. Modern frameworks do this — follow them.
