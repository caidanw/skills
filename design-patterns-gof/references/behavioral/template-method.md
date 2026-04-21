# Template Method

**Category:** Behavioral · **Modern relevance:** Mostly framework internals. Prefer Strategy.

## Intent

Define the skeleton of an algorithm in a base class, letting subclasses override specific steps
without changing the algorithm's overall structure.

## Problem

Several classes implement near-identical algorithms that differ only in a few steps. Copy-paste
duplicates the skeleton; every fix must be replicated.

## Structure

- **Abstract Class** with a `templateMethod()` that calls step methods in order. Steps are either
  abstract or have sensible defaults (hooks).
- **Concrete Subclasses** override specific steps but never the template method itself.

## Applicability

- Multiple variants of an algorithm share structure and differ in details.
- Lock down the overall order of operations but allow extension points.
- Frameworks exposing lifecycle hooks (setUp/run/tearDown).

## Consequences

**Pros:** Eliminates duplication. Enforces algorithm order invariants. Simple to understand.

**Cons:** Inheritance-based (rigid). Skeleton is fixed. Easy to violate LSP. Hard to reason about
control flow as a subclass author — you don't see when your overrides will be called.

## When NOT to use

- Subclass chains get deep.
- Multiple axes of variation cross-cut.
- You need runtime flexibility or multiple independent variation points → **Strategy** is better.

## Modern relevance

Heavy inside frameworks, less in application code. Test frameworks' `setUp`/`tearDown`/`beforeEach`/
`afterEach` hooks are Template Method. React class lifecycle (`componentDidMount`, `render`) was
Template Method; hooks are more compositional. Django class-based views, Rails ActionController,
Spring's `JdbcTemplate`, Android Activity lifecycle — all Template Method. In application code,
prefer Strategy.

## Code sketch (Python)

```python
from abc import ABC, abstractmethod

class Report(ABC):
    def generate(self):                 # the template method
        self.load()
        data = self.transform(self.raw)
        self.save(self.format(data))

    def load(self): self.raw = self._fetch()
    def format(self, d): return str(d)  # hook with default
    @abstractmethod
    def _fetch(self): ...
    @abstractmethod
    def transform(self, raw): ...
    @abstractmethod
    def save(self, out): ...

class CsvReport(Report):
    def _fetch(self):       return [("a", 1), ("b", 2)]
    def transform(self, r): return "\n".join(f"{k},{v}" for k, v in r)
    def save(self, out):    print(out)
```

## Real-world uses

- JUnit/pytest/xctest `setUp`/`tearDown`
- Django generic views
- Rails ActionController filters
- Android Activity lifecycle
- Servlet `doGet`/`doPost`
- Spring `JdbcTemplate`, `RestTemplate`
- Build tool lifecycles (Maven phases)

## Distinguishing from neighbors

- **vs. Strategy** — Inheritance vs. composition. Template Method: one algorithm, locked shape,
  hook methods. Strategy: swappable whole algorithms. **Composition-over-inheritance favors
  Strategy.**
- **vs. Factory Method** — Factory Method is often *a step within* a Template Method.

## Functional equivalent

Higher-order functions. A function taking `fetch`, `transform`, `save` callbacks replaces the
inheritance entirely. Modern frameworks prefer this (middleware, hooks, builder callbacks).

## Rule of thumb

Prefer Strategy. Reach for Template Method only when you control a framework and want users to
subclass. In application code, the shape almost always rewrites more cleanly as a function that
takes callbacks.
