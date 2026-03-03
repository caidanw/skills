# Progressive Disclosure for Agent Context

Agents work best when they start with minimal context and drill deeper as needed. Dumping
everything into a single file or prompt overwhelms the context window and degrades
performance. Structure documentation in layers.

## The Three Layers

### Layer 1: Entry Point (~100 lines)

`AGENTS.md` — always loaded. Contains dev commands, repo structure overview, architecture
boundaries, coding standards, and **pointers** to deeper docs.

This file answers: "How do I build, test, and navigate this project?"

### Layer 2: Architecture & Design (~200-400 lines)

`ARCHITECTURE.md` — loaded when the agent needs to understand how modules relate, where to
make changes, and what invariants to respect.

This file answers: "Where is the thing that does X?" and "What does this thing I'm looking
at do?"

For how to write an effective ARCHITECTURE.md with codemaps, boundary markers, and
invariant callouts, see the `architecture-md` skill.

### Layer 3: Domain-Specific Docs (loaded on demand)

The `docs/` tree — loaded only when the agent is working in a specific domain or needs
detailed context. The agent discovers these through pointers in Layers 1 and 2.

These files answer: "What are the detailed requirements, design decisions, and constraints
for this specific area?"

## Directory Structure

```
docs/
├── design-docs/
│   ├── index.md              # Catalogue: title, status, date, owner
│   ├── core-beliefs.md       # Foundational principles (agent-first, etc.)
│   ├── auth-architecture.md  # How auth works end-to-end
│   └── data-pipeline.md      # ETL design and constraints
├── exec-plans/
│   ├── active/
│   │   └── migrate-to-v2.md  # Current work with progress log
│   ├── completed/
│   │   └── initial-launch.md # Done, kept for context
│   └── tech-debt-tracker.md  # Prioritized list of known debt
├── product-specs/
│   ├── index.md              # Catalogue of product specs
│   ├── onboarding-flow.md    # User journey, acceptance criteria
│   └── billing.md            # Billing domain spec
├── references/
│   ├── stripe-llms.txt       # LLM-friendly Stripe API reference
│   └── postgres-patterns.md  # DB patterns specific to this project
└── generated/
    └── db-schema.md          # Auto-generated, never hand-edited
```

## Index Files

Every directory with more than 2-3 documents should have an `index.md` that catalogues
its contents with metadata:

```markdown
# Design Documents

| Document | Status | Last Updated | Summary |
|---|---|---|---|
| [auth-architecture.md](auth-architecture.md) | Approved | 2025-12-01 | OAuth2 + session tokens |
| [data-pipeline.md](data-pipeline.md) | Draft | 2025-11-15 | ETL from Postgres to analytics |
```

Status values: `Draft`, `In Review`, `Approved`, `Superseded`, `Deprecated`.

This gives the agent a fast scan of what exists without reading every document.

## Cross-Linking

Documents should reference each other by relative path. When a design doc references
an architectural concept, link to ARCHITECTURE.md. When a product spec has technical
constraints, link to the relevant design doc.

```markdown
<!-- In a product spec -->
This feature requires changes to the auth layer. See the
[auth architecture](../design-docs/auth-architecture.md) for boundary constraints.
```

Don't deep-link to specific line numbers or sections — they go stale. Link to documents
and let the agent search within them.

## Freshness Validation

Stale docs are worse than no docs — agents follow them faithfully. Maintain freshness with:

**Mechanical checks:**
- CI job that validates all index files list every document in their directory
- Lint that checks cross-links resolve to existing files
- Warning on docs not updated in 90+ days (configurable)

**Doc-gardening cadence:**
- Run a recurring agent task that scans docs against the actual codebase
- Flag docs that reference modules, types, or files that no longer exist
- Open targeted fix-up PRs for stale references

**Metadata in frontmatter:**

```markdown
---
status: approved
last_reviewed: 2025-12-01
owner: @team-platform
---
```

This makes freshness queryable by both agents and CI.

## Execution Plans as First-Class Artifacts

For complex multi-step work, write execution plans that track progress:

```markdown
# Migrate to API v2

## Status: In Progress (Step 3 of 5)

## Goal
Migrate all endpoints from v1 to v2 with zero downtime.

## Steps
1. [x] Define v2 schema types
2. [x] Implement v2 endpoints alongside v1
3. [ ] Migrate frontend to v2 endpoints  <-- CURRENT
4. [ ] Add deprecation headers to v1
5. [ ] Remove v1 after 30-day deprecation window

## Decision Log
- 2025-11-20: Chose parallel deployment over feature flags (simpler rollback)
- 2025-11-22: Added 30-day deprecation window per API policy

## Known Risks
- Frontend has 3 undocumented v1 endpoint usages (tracked in tech-debt-tracker.md)
```

Plans are versioned, co-located with the code, and readable by both agents and humans.
Active plans live in `docs/exec-plans/active/`, completed plans move to `completed/`.

## Key Principles

- **Start lean, grow as needed.** Don't create the full `docs/` tree on day one. Start with AGENTS.md + ARCHITECTURE.md and add docs as complexity demands.
- **Every doc has one job.** If a document covers two unrelated topics, split it.
- **Index files are mandatory** once a directory has 3+ documents.
- **Stale docs are bugs.** Treat them with the same urgency as stale tests.
- **The agent discovers, not memorizes.** Pointers from AGENTS.md → ARCHITECTURE.md → docs/ let the agent load context incrementally.
