# Adapter

**Category:** Structural · **Modern relevance:** Ubiquitous at system boundaries

## Intent

Let two objects with incompatible interfaces collaborate by wrapping one in a translator that
speaks the interface the other expects.

## Problem

Working code expects interface `A`. A useful class (often third-party or legacy) exposes `B`. You
can't or shouldn't edit either side. Without an adapter, conversion logic sprinkles through
business code and rots.

## Structure

- **Client** — business logic; talks only to `ClientInterface`.
- **ClientInterface** — the protocol the client understands.
- **Service** — the useful but mismatched class.
- **Adapter** — implements `ClientInterface`, wraps a `Service`, translates calls/data.

Two flavors: *object adapter* (composition — default in modern code) and *class adapter* (multiple
inheritance — mostly C++).

## Applicability

- Integrating a third-party SDK you can't change.
- Wrapping a legacy module during incremental migration (strangler pattern).
- Normalizing heterogeneous data sources (XML API vs. JSON API) to one internal shape.
- Making old subclasses work in a new type hierarchy without duplicating code.

## Consequences

**Pros:** Isolates conversion logic (SRP). New adapters don't break existing code (OCP). Keeps
third-party concerns at the edge.

**Cons:** Another layer of indirection. Extra classes. Sometimes cheaper to just edit the caller.

## When NOT to use

- You control both sides — just fix the interface directly.
- The "mismatch" is one method with two arguments swapped. A one-line helper beats a class.
- Adapting something once, in one place — inline the conversion.

## Modern relevance

Extremely high, usually invisible. Node.js streams adapt callback APIs to streaming APIs. ORMs
adapt SQL rows to domain objects. Cloud SDKs adapt REST to typed clients. TanStack Query adapts
fetch promises to declarative hooks. Anywhere your system boundary meets foreign code, an adapter
lives there.

## Code sketch (TypeScript)

```ts
interface Analytics { track(event: string, props: Record<string, unknown>): void }

class SegmentSDK {
  send(payload: { name: string; data: string }) { /* third-party */ }
}

class SegmentAdapter implements Analytics {
  constructor(private sdk: SegmentSDK) {}
  track(event: string, props: Record<string, unknown>) {
    this.sdk.send({ name: event, data: JSON.stringify(props) })
  }
}

const analytics: Analytics = new SegmentAdapter(new SegmentSDK())
analytics.track("signup", { plan: "pro" })
```

## Real-world uses

- Node `stream.Readable.from()` (iterable → stream)
- Java `Arrays.asList`
- Python `io.TextIOWrapper` (bytes → text)
- React synthetic events adapting DOM events
- `axios` adapters for XHR vs. Node http

## Distinguishing from neighbors

- **vs. Facade** — Adapter changes *one* interface to match an expected one. Facade defines a
  *new, simpler* interface over a *subsystem of many*. Adapter: "how do I plug this in?" Facade:
  "how do I hide all this?"
- **vs. Bridge** — Adapter is retrofit; Bridge is pre-planned decoupling.
- **vs. Proxy** — Proxy preserves the interface; Adapter deliberately changes it.
- **vs. Decorator** — Decorator keeps interface and adds behavior; Adapter changes interface.

## Rule of thumb

If the code lives at the border between your system and someone else's (library, network, file
format), Adapter is almost always the right name. Keep them thin; conversion logic only.
