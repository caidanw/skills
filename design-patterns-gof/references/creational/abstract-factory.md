# Abstract Factory

**Category:** Creational · **Modern relevance:** Low–moderate (DI containers absorbed most uses)

## Intent

Produce **families of related objects** through a single interface, without specifying their
concrete classes. The guarantee: products returned from the same factory are compatible with one
another.

## Problem

You have multiple product categories (`Button`, `Checkbox`, `Menu`) that come in multiple
"skins" (macOS, Windows, Linux). Mixing a `MacButton` with a `WindowsCheckbox` would look wrong or
break. Clients need to create a *coherent set* without knowing which variant they're in.

## Structure

- **Abstract Products** — one interface per product category.
- **Concrete Products** — grouped by variant.
- **Abstract Factory** — one creation method per product category.
- **Concrete Factories** — each produces one coherent family.
- **Client** — receives a factory at startup, calls abstract methods only.

## Applicability

- Cross-platform UI toolkits.
- Swappable backends whose products must co-vary (SQL dialect: `QueryBuilder` + `Dialect` + `TypeMapper`).
- Theme systems where widgets share a visual language.
- Test doubles: a `FakeAwsFactory` producing `FakeS3`, `FakeSqs`, `FakeDynamo` sharing in-memory state.

## Consequences

**Pros:** Guarantees family compatibility. Decouples client from concrete classes. Centralizes
creation. Open/Closed for new *families*.

**Cons:** Class count explodes. Every new *product category* forces edits to the factory interface
*and every concrete factory*. The matrix grows multiplicatively.

## When NOT to use (over-abstraction warnings)

- You have **one** product family and "might add another someday." You won't. Delete it.
- You're using it to hide a single `if (platform === "mac")` branch.
- Your products don't need to co-vary — each is independently swappable. Use separate Factory Methods or DI.
- In TS/Python, a plain object literal mapping names to constructors does 90% of the job.

## Modern relevance

Dependency injection containers (Spring, NestJS, Wire, FastAPI's `Depends`) largely subsumed this.
You register a set of implementations per environment and the container wires them. The explicit
`AbstractFactory` class hierarchy is a Java/C++ artifact. Still useful in cross-platform SDKs
(AWS CDK cloud assembly providers, React Native platform modules, Qt `QStyle`).

## Code sketch (TypeScript)

```ts
interface Button { render(): string }
interface Checkbox { render(): string }

interface UIFactory {
  createButton(): Button
  createCheckbox(): Checkbox
}

class MacFactory implements UIFactory {
  createButton()   { return { render: () => "[ macOS button ]" } }
  createCheckbox() { return { render: () => "[x] macOS check" } }
}
class WinFactory implements UIFactory {
  createButton()   { return { render: () => "|_Win button_|" } }
  createCheckbox() { return { render: () => "[X] Win check" } }
}

function renderApp(ui: UIFactory) {
  console.log(ui.createButton().render(), ui.createCheckbox().render())
}
renderApp(process.platform === "darwin" ? new MacFactory() : new WinFactory())
```

## Real-world uses

- `javax.xml.parsers.DocumentBuilderFactory`
- AWS SDK service clients (each `ClientBuilder` is a family factory)
- React Native `Platform`-specific module resolution
- Qt `QStyle` (consistent theming across widgets)

## Distinguishing from neighbors

- **vs. Factory Method** — Abstract Factory *is a set of* Factory Methods grouped by family. Factory Method is one create-operation; Abstract Factory is several that must agree.
- **vs. Builder** — Builder assembles one complex object step-by-step; Abstract Factory produces several related objects.
- **vs. Prototype** — Abstract Factory is often *implemented with* Prototype (each factory holds prototype instances and clones them).

## Rule of thumb

Reach for it when you have **≥2 product categories × ≥2 variants** *today* and the variants must
match. Below that threshold, DI or a simple factory function wins.
