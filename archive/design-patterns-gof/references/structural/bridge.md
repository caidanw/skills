# Bridge

**Category:** Structural · **Modern relevance:** Moderate (often unnamed; DI with interfaces is Bridge)

## Intent

Split a class that varies along two independent axes into two hierarchies — abstraction and
implementation — linked by composition, so each can evolve separately.

## Problem

Inheritance is 1-dimensional. Shapes × colors × rendering backends produces a Cartesian explosion
(`RedCircleSVG`, `BlueSquareCanvas`, …). Bridge replaces the product with a sum.

## Structure

- **Abstraction** — high-level logic; holds a reference to an Implementation.
- **RefinedAbstraction** — variants of high-level logic.
- **Implementation** — interface for low-level operations.
- **ConcreteImplementation** — platform/backend specifics.
- **Client** — wires Abstraction to Implementation.

## Applicability

- A class mixes two orthogonal concerns (*what* to draw vs. *how* to draw it).
- Swap implementations at runtime (cross-platform rendering, DB drivers).
- You foresee both axes growing.

## Consequences

**Pros:** Clean SRP/OCP split. Platform-independent business logic. Runtime swap.

**Cons:** Upfront complexity. For single-axis classes it's pure ceremony.

## When NOT to use

- One axis of variation today and no strong reason to expect a second. YAGNI.
- Both "hierarchies" are one-deep. You invented an interface for nothing.
- Cohesion is already high — splitting harms readability.

## Modern relevance

Rarely taught as "Bridge" but ubiquitous in spirit: dependency injection with interface-typed
fields *is* Bridge. Examples: JDBC `Driver`/`Connection`, Python DB-API, `slog.Handler` in Go,
React's reconciler/renderer split (`react-dom` vs. `react-native` share `react`), logging frameworks
(`Logger` abstraction + `Appender` implementations).

## Code sketch (Python)

```python
from abc import ABC, abstractmethod

class Renderer(ABC):                              # Implementation
    @abstractmethod
    def draw_circle(self, x: float, y: float, r: float) -> None: ...

class SVGRenderer(Renderer):
    def draw_circle(self, x, y, r): print(f'<circle cx="{x}" cy="{y}" r="{r}"/>')

class CanvasRenderer(Renderer):
    def draw_circle(self, x, y, r): print(f"ctx.arc({x},{y},{r},0,2*PI)")

class Shape:                                      # Abstraction
    def __init__(self, renderer: Renderer): self.renderer = renderer

class Circle(Shape):                              # RefinedAbstraction
    def __init__(self, renderer, x, y, r):
        super().__init__(renderer); self.x, self.y, self.r = x, y, r
    def draw(self): self.renderer.draw_circle(self.x, self.y, self.r)

Circle(SVGRenderer(), 10, 10, 5).draw()
```

## Real-world uses

- JDBC, ODBC, Python DB-API
- React renderer abstraction (`react-dom` / `react-native` / `react-three-fiber`)
- Flutter's `RenderObject` / platform-channel split
- Qt's `QPaintDevice` / `QPaintEngine`

## Distinguishing from neighbors

- **vs. Adapter** — Same shape (one object refs another that does work), different intent. Bridge
  is pre-planned decoupling; Adapter is after-the-fact reconciliation.
- **vs. Strategy** — Strategy swaps an algorithm inside an object; Bridge separates an *entire
  dimension* of the class. Structurally similar, semantically different. Bridge implementations are
  usually fatter (many methods); Strategies are typically one method.

## Rule of thumb

Reach for Bridge when a class is genuinely splitting along two axes and both are expected to grow.
Otherwise, prefer Strategy for a single varying algorithm or plain composition for single-axis
injection.
