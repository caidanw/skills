# Prototype

**Category:** Creational · **Modern relevance:** Low in app code; high in game engines / scene graphs

## Intent

Create new objects by **cloning an existing instance** rather than instantiating a class. The
prototype carries its own copy logic.

## Problem

Copying an object from outside is hard: private fields are hidden, you may only know the interface,
and pre-configuring a fresh instance to match an existing one duplicates setup logic. Subclassing
to pre-seed config (`NorthernEuropeanDefaultOrder`, `USDefaultOrder`) creates a dummy class
explosion.

## Structure

- **Prototype** interface with `clone()`.
- **Concrete Prototype** — implements `clone()`, usually deep, handling private fields and cycles.
- **Client** — clones any prototype it holds, without knowing the concrete class.
- **Prototype Registry (optional)** — keyed store of pre-configured prototypes
  (`"default-admin-user"`, `"spam-email-template"`).

## Applicability

- Cloning objects whose concrete class you don't know (you only hold an interface).
- Avoiding expensive reconstruction (deserialization, DB hydration).
- Replacing a forest of "preset" subclasses with a registry of configured instances.
- Undo/redo, snapshotting game state, memoizing complex AST nodes.

## Consequences

**Pros:** Decouples cloning from concrete class. Avoids reinitializing expensive objects. Good
alternative to inheritance for config variations.

**Cons:** Deep cloning with **circular references** is painful. Shallow-vs-deep intent is
non-obvious. Cloned objects may share mutable substate by accident (aliasing bugs).

## When NOT to use

- Your objects are cheap to construct. Just construct them.
- You reach for it because you're scared of `new` — that's not a reason.
- Your language has `structuredClone` (modern JS), `copy.deepcopy` (Python), `#[derive(Clone)]`
  (Rust). Unless cloning has *semantics* beyond "copy bytes" (reset IDs, detach from DB session),
  just use those.
- In immutable-data codebases (Redux, Elm-style), cloning is irrelevant.

## Modern relevance

JavaScript is named after prototypal inheritance, but the *design pattern* there is usually solved
by `structuredClone`, spread, or immer. Genuinely useful for:

- Game engines (Unity/Unreal/Godot prefabs — `Instantiate(prefab)` is textbook Prototype).
- Graphics / scene graphs (Three.js `Object3D.clone()`).
- Document editors (copy-paste of rich objects).
- Test fixtures (Factory-Bot-style libraries clone baseline records).

## Code sketch (Python)

```python
from copy import deepcopy
from dataclasses import dataclass, field

@dataclass
class Enemy:
    name: str
    hp: int
    loot: list[str] = field(default_factory=list)

    def clone(self) -> "Enemy":
        copy = deepcopy(self)
        copy.name = f"{self.name} (clone)"  # cloning semantics > raw copy
        return copy

registry: dict[str, Enemy] = {
    "goblin": Enemy("Goblin", hp=10, loot=["copper"]),
    "dragon": Enemy("Dragon", hp=500, loot=["gold", "scale"]),
}

def spawn(kind: str) -> Enemy:
    return registry[kind].clone()

boss = spawn("dragon")
boss.hp = 9999  # independent of prototype
```

## Real-world uses

- JavaScript `Object.create(proto)`, `structuredClone`
- Java `Cloneable` / `Object.clone()` (widely considered broken, but canonical)
- Unity/Unreal prefabs
- Three.js `Mesh.clone()`
- Django's `Model(instance).pk = None; instance.save()` idiom

## Distinguishing from neighbors

- **vs. Abstract Factory** — Prototype *implements* Abstract Factory when the factory holds
  prototype instances and clones them.
- **vs. Memento** — Prototype clones for duplication; Memento clones for rollback.
- **vs. Builder** — Builder assembles from parts; Prototype copies a finished instance.

## Rule of thumb

If you're cloning for *data duplication*, use the language's built-in deep copy. Reach for Prototype
as a pattern name when cloning has domain semantics (spawn an enemy, instantiate a prefab, fork a
document) and the "templates" benefit from being runtime values rather than classes.
