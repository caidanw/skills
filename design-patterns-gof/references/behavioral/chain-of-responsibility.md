# Chain of Responsibility

**Category:** Behavioral · **Modern relevance:** Ubiquitous as middleware

## Intent

Pass a request along a linear chain of handlers; each handler decides to process it, transform it,
or forward it to the next.

## Problem

Pipeline of independent checks or processing steps (auth, validation, rate-limiting, caching,
logging). Cramming them into one method creates a monolith that's hard to reorder, skip, or extend.
Each step should be reusable and reorderable.

## Structure

- **Handler** interface with `handle(request)` and a link to `next`.
- **Base Handler** stores `next`, provides default forwarding.
- **Concrete Handlers** implement processing; decide to short-circuit or call `next`.
- **Client** assembles the chain, fires the request at its head.

## Applicability

- Multiple objects may handle a request; the specific handler isn't known up front.
- Handlers and order must be configurable at runtime.
- Avoid explicit conditionals selecting a handler.
- Classic cases: HTTP middleware, event bubbling, logging levels, approval workflows.

## Consequences

**Pros:** Single-responsibility handlers. Open/closed for new handlers. Dynamic composition.

**Cons:** A request can silently go unhandled. Chain flow is hard to debug. Indirection hides the
actual code path.

## When NOT to use

- The set of steps is fixed and always runs in the same order — use a flat function.
- Short-circuiting is rare — you don't need the pattern.

## Modern relevance

Extremely alive, usually unnamed. Express/Koa/Connect middleware, ASP.NET middleware, Redux
middleware, AWS Lambda middleware (Middy), most API gateways. GoF's linked-list-of-objects is
replaced with an array of functions composed at startup.

## Code sketch (TypeScript)

```ts
type Ctx = { user?: string; path: string; body: unknown }
type Next = () => Promise<void>
type Middleware = (ctx: Ctx, next: Next) => Promise<void>

const auth: Middleware = async (ctx, next) => {
  if (!ctx.user) throw new Error("401")
  await next()
}
const log: Middleware = async (ctx, next) => {
  console.log("->", ctx.path)
  await next()
  console.log("<-", ctx.path)
}

const run = (mws: Middleware[]) => (ctx: Ctx) => {
  const dispatch = (i: number): Promise<void> =>
    i >= mws.length ? Promise.resolve() : mws[i](ctx, () => dispatch(i + 1))
  return dispatch(0)
}

run([log, auth])({ user: "ada", path: "/me", body: null })
```

## Real-world uses

- Express/Koa middleware
- Java servlet filters
- DOM event propagation / capture+bubble
- Winston log transports
- iOS UIResponder chain
- log4j logger hierarchy
- Exception handling (try/catch/throw)

## Distinguishing from neighbors

- **vs. Decorator** — Same linked structure, different semantics. Decorator always forwards and
  augments; CoR can short-circuit. Decorator composes *behavior*; CoR chooses a *handler*.
- **vs. Pipeline** — Pipeline is a strict CoR where every stage runs and transforms — no
  short-circuiting.
- **vs. Observer** — Observer broadcasts to all subscribers independently; CoR passes sequentially
  until one handles it.

## Functional equivalent

Array of `(ctx, next) => ...` functions reduced via composition. The handler classes collapse to
closures — which is how every modern middleware framework implements it.

## Rule of thumb

If handlers have a natural fixed order, inline them. If order/membership is dynamic or
configurable, use a middleware list (functional CoR). Reach for the class-based GoF form only when
handlers carry significant state or lifecycle.
