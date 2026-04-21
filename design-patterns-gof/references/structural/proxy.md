# Proxy

**Category:** Structural · **Modern relevance:** Enormous (ORMs, RPC stubs, reactivity, middleware)

## Intent

Substitute another object that implements the same interface as a real service, so you can control
access — lazy creation, caching, auth, logging, remoting — transparently to the client.

## Problem

You need to interpose behavior around every access to an object, but you don't want clients to
know, and you can't (or shouldn't) modify the real service. Common drivers: expensive to
instantiate, lives over the network, access must be guarded.

## Structure

- **ServiceInterface** — the contract.
- **Service** — real implementation.
- **Proxy** — implements the interface, holds a `Service` reference, interposes logic (lazy init,
  auth, caching, logging) before/around/after delegation.
- **Client** — holds a `ServiceInterface`, doesn't know which it has.

## Flavors

- **Virtual proxy** — lazy-instantiate an expensive object (ORM entities loaded on field access).
- **Remote proxy** — local stub for a remote service (RPC, gRPC stubs).
- **Protection proxy** — enforce auth/permissions.
- **Caching proxy** — memoize results.
- **Logging/metrics proxy** — observe calls.
- **Smart reference** — refcounting, copy-on-write.

## Consequences

**Pros:** Transparent interposition. Client untouched. OCP-friendly. Lifecycle control.

**Cons:** More classes. Subtle bugs when proxy and service diverge semantically (e.g., lazy proxy
returning stale data). Extra indirection cost. `this`/identity issues.

## When NOT to use

- Interposed logic belongs *in* the service itself (e.g., internal caching).
- Only one call site — wrap it there.
- Your language gives you a better tool: Python `__getattr__`, JS `Proxy`, Java dynamic proxies,
  annotations. Often replaces a handwritten Proxy class with a few lines.

## Modern relevance

Enormous. ORMs use virtual proxies for lazy loading (Hibernate, SQLAlchemy, Prisma).
gRPC/tRPC/GraphQL client stubs are remote proxies. Vue 3's reactivity is built on `Proxy`. MobX
observables are proxies. Service meshes (Envoy, Linkerd) are process-level proxies. Authorization
middleware is a protection proxy.

## Code sketch (TypeScript)

```ts
interface Images { get(id: string): Promise<Blob> }

class RealImages implements Images {
  async get(id: string) { return fetch(`/img/${id}`).then(r => r.blob()) }
}

class CachingImageProxy implements Images {
  private cache = new Map<string, Blob>()
  constructor(private real: Images) {}
  async get(id: string) {
    const hit = this.cache.get(id)
    if (hit) return hit
    const blob = await this.real.get(id)
    this.cache.set(id, blob)
    return blob
  }
}

const images: Images = new CachingImageProxy(new RealImages())
```

## Real-world uses

- Hibernate/SQLAlchemy/Prisma lazy relations
- JS `Proxy` in Vue reactivity, Immer
- Java RMI stubs, gRPC generated clients
- Envoy/Istio (network proxy)
- CDN edge caches (literal HTTP proxies)
- Python `unittest.mock.MagicMock`
- React Server Components client references

## Distinguishing from neighbors

- **vs. Decorator** — Both preserve interface. Decorator *adds* orthogonal behavior, stacked by
  *client*. Proxy *controls access* to a specific service, typically *owns* its lifecycle. One
  Proxy, many Decorators.
- **vs. Adapter** — Proxy keeps interface; Adapter changes it.
- **vs. Facade** — Proxy mirrors one object's full interface; Facade invents a narrower one over
  many.

## Rule of thumb

Proxy is the right answer at boundaries where *access* needs control (network, security, lazy
loading). If the interposed behavior is *the point* rather than a boundary concern, you want
Decorator instead.
