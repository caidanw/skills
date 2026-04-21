# Flyweight

**Category:** Structural · **Modern relevance:** Niche (graphics, text rendering, ECS)

## Intent

Cram more objects into memory by sharing the parts of state that don't vary between instances
(intrinsic), and passing the rest in from outside (extrinsic).

## Problem

You need millions of objects (particles, glyphs, tiles, trees in a forest), and naive per-instance
storage blows your RAM budget. Most of each object's state is duplicated.

## Structure

- **Flyweight** — holds intrinsic (shared, immutable) state.
- **Context** — holds extrinsic (unique) state; references a Flyweight.
- **FlyweightFactory** — hash-consing cache; returns an existing Flyweight if one matches.
- **Client** — computes extrinsic state, asks the factory for a Flyweight.

## Applicability

- *Very* large number of similar objects.
- State cleanly splits into "shared" and "per-instance."
- Memory is the binding constraint and has been measured.

## Consequences

**Pros:** Dramatic memory reduction.

**Cons:** Extra CPU to look up/compose extrinsic state. Significantly more complex code. Intrinsic
state must be immutable or you corrupt every sharer. Debugging harder — objects lose identity.

## When NOT to use

- You haven't profiled. Don't optimize memory you haven't measured.
- Object counts in the thousands, not millions. Modern machines don't care.
- "Shared" state varies slightly per instance on inspection.
- Your language already handles it (Python small ints, Java `String.intern()`, JS engine hidden
  classes).

## Modern relevance

Narrow but real. Heavy use in game engines (instanced rendering, sprite atlases, tilemaps), text
rendering (glyph caches — Harfbuzz, FreeType, terminal emulators including Ghostty), browsers (CSS
style sharing), ML (embedding tables). Outside graphics/systems, you almost never reach for it
explicitly — though string interning, enum values, and shared immutable config are Flyweight in
disguise.

## Code sketch (TypeScript)

```ts
class TreeType {                              // Flyweight (intrinsic)
  constructor(readonly name: string, readonly texture: ImageBitmap) {}
  draw(ctx: CanvasRenderingContext2D, x: number, y: number) {
    ctx.drawImage(this.texture, x, y)
  }
}

class TreeTypeFactory {                       // pool
  private static pool = new Map<string, TreeType>()
  static get(name: string, texture: ImageBitmap): TreeType {
    let t = this.pool.get(name)
    if (!t) { t = new TreeType(name, texture); this.pool.set(name, t) }
    return t
  }
}

class Tree {                                  // Context (extrinsic)
  constructor(private x: number, private y: number, private type: TreeType) {}
  draw(ctx: CanvasRenderingContext2D) { this.type.draw(ctx, this.x, this.y) }
}
// 1M Trees share a handful of TreeTypes.
```

## Real-world uses

- Java `Integer.valueOf` cache
- Python small int and interned string pools
- Browser CSS computed-style sharing
- Glyph atlases in every text renderer
- `Boolean.TRUE`/`Boolean.FALSE`
- ECS component pools in game engines

## Distinguishing from neighbors

- **vs. Singleton** — Singleton is one instance, often mutable, for identity. Flyweight is *many*
  shared immutable instances for memory.
- **vs. Cache** — A cache speeds up recomputation; a Flyweight dedupes storage. They often coexist
  (the factory's pool *is* a cache).
- **vs. Object Pool** — Pool reuses mutable objects to avoid allocation; Flyweight shares immutable
  ones to save memory.

## Rule of thumb

Profile first. Flyweight is almost always the wrong default — but the right answer when memory
is measured and significant, and the state cleanly factors into shared-immutable and unique-mutable.
