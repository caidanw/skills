# Mechanical Enforcement

Encode architectural rules as linters and tests, not prose documentation. Prose gets
ignored by agents (and humans). CI failures don't. When documentation falls short,
promote the rule into code.

## The Principle

> Enforce invariants, not implementations. Let agents ship fast without undermining
> the foundation.

Specify **what** must hold (e.g., "parse data at boundaries"), not **how** to do it
(e.g., "use Zod"). Agents are effective at finding solutions within constraints.

This mirrors the type-driven design principle of making illegal states unrepresentable.
Rather than documenting "don't pass raw strings where emails are expected," define an
`EmailAddress` type that can only be created through parsing. The type system becomes
the enforcer. For the full treatment, see the `parse-dont-validate` skill.

## Lint Error Messages as Remediation Instructions

The most impactful pattern: write custom lint error messages that tell the agent
exactly how to fix the violation.

```ts
// Custom ESLint rule
module.exports = {
  create(context) {
    return {
      ImportDeclaration(node) {
        const source = node.source.value;
        const file = context.getFilename();

        if (file.includes("/store/") && source.includes("/api/")) {
          context.report({
            node,
            message:
              "Store modules cannot import from the API layer. " +
              "If you need a shared type, move it to src/types/. " +
              "If you need API functionality, create a store interface " +
              "and have the API layer call into it instead.",
          });
        }
      },
    };
  },
};
```

The error message IS the documentation. When the agent hits this lint failure, it
receives the remediation instructions directly in its error output — no need to
search through docs.

## Structural Dependency Tests

Validate that module dependencies flow in the correct direction:

```ts
import { readdir } from "node:fs/promises";
import { join } from "node:path";

// Test: store/ never imports from api/
test("store modules do not depend on api layer", async () => {
  const storeFiles = await glob("src/store/**/*.ts");
  for (const file of storeFiles) {
    const content = await Bun.file(file).text();
    const imports = content.match(/from\s+['"]([^'"]+)['"]/g) ?? [];
    for (const imp of imports) {
      expect(imp).not.toMatch(/\/api\//);
    }
  }
});

// Test: types/ has zero internal dependencies
test("types module has no internal dependencies", async () => {
  const typeFiles = await glob("src/types/**/*.ts");
  for (const file of typeFiles) {
    const content = await Bun.file(file).text();
    const internalImports = (content.match(/from\s+['"]\.\.\/(?!types)/g) ?? []);
    expect(internalImports).toHaveLength(0);
  }
});
```

These tests are cheap to run, never flaky, and catch violations immediately.

## Layer Architecture with Permitted Edges

Define layers and their allowed dependency directions explicitly:

```ts
const LAYERS = {
  types:    { allowed: [] },                           // depends on nothing
  config:   { allowed: ["types"] },                    // depends on types only
  store:    { allowed: ["types", "config"] },           // no api, no worker
  service:  { allowed: ["types", "config", "store"] },  // no api, no ui
  api:      { allowed: ["types", "config", "store", "service"] },
  worker:   { allowed: ["types", "config", "store", "service"] },
  ui:       { allowed: ["types", "config", "service"] }, // no direct store access
};

test.each(Object.entries(LAYERS))("%s respects layer boundaries", async (layer, { allowed }) => {
  const files = await glob(`src/${layer}/**/*.ts`);
  for (const file of files) {
    const content = await Bun.file(file).text();
    const imports = [...content.matchAll(/from\s+['"]\.\.\/(\w+)/g)].map(m => m[1]);
    for (const dep of imports) {
      if (dep === layer) continue; // intra-layer is fine
      expect(allowed).toContain(dep);
    }
  }
});
```

Visualize this as a DAG: arrows only point "downward" toward more foundational layers.
Cross-cutting concerns (auth, telemetry, feature flags) enter through an explicit
Providers interface.

## What to Enforce Mechanically

**High-value, low-noise rules:**
- Dependency direction between layers
- No `console.log` (use structured logger)
- Structured logging format (key-value pairs, not string interpolation)
- Naming conventions for types, schemas, database columns
- File size limits (e.g., no file over 500 lines without review)
- No `any` or `as` type assertions in production code
- Import restrictions (which modules can import from where)
- Required test coverage for new files

**Rules better left as documentation:**
- "Prefer composition over inheritance" — too subjective for a lint
- "Write clear variable names" — can't be mechanically checked
- "Consider performance implications" — context-dependent

## Enforce Boundaries Centrally, Allow Autonomy Locally

The enforcement philosophy mirrors platform engineering: strict rules at system
boundaries, freedom within them.

**Central enforcement (non-negotiable):**
- Layer dependency directions
- API boundary contracts (typed, validated)
- Security boundaries (no secrets in code, auth required on endpoints)
- Data integrity (migrations are forward-only, schema changes are validated)

**Local autonomy (team/module decides):**
- Internal module structure
- Implementation patterns within a layer
- Test organization within a module
- Helper function naming within a file

The goal is that an agent can make changes freely within a module while being
mechanically prevented from violating cross-cutting architectural rules.

## CI as the Final Arbiter

Every mechanical enforcement rule should be a CI check. The merge gate is:
1. Lints pass (dependency rules, naming, structure)
2. Type check passes (boundary types are correct)
3. Structural tests pass (layer tests, no circular deps)
4. Unit/integration tests pass (behavior is correct)

If a rule matters, it's in CI. If it's not in CI, it's a suggestion, not a rule.
Agents (and humans) treat these very differently.
