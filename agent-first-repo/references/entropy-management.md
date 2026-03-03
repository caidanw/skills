# Entropy Management

Agent-generated code drifts. Agents replicate existing patterns — including bad ones.
Without active maintenance, the codebase accumulates inconsistency and technical debt
faster than a human-only codebase would. Entropy management is the discipline of
keeping this under control.

> Technical debt is like a high-interest loan: it's almost always better to pay it
> down continuously in small increments than to let it compound and tackle it in
> painful bursts.

## The Problem

OpenAI's harness engineering team initially spent every Friday (20% of the week)
manually cleaning up "AI slop." This doesn't scale.

The failure mode: agents see a pattern used 15 times in the codebase, replicate it
in new code, and now it's used 16 times. If the pattern is suboptimal, each new
usage makes it harder to refactor. The bad pattern becomes the dominant pattern,
and the agent treats it as the convention.

## Golden Principles

Golden principles are opinionated, mechanical, verifiable rules that define what
"good" looks like in your codebase. They serve two purposes:
1. Guide agents during code generation (referenced from AGENTS.md)
2. Power automated scans that detect violations

**Characteristics of a good golden principle:**
- **Mechanical** — Can be checked programmatically, not just by human judgment
- **Opinionated** — Takes a clear stance, not "it depends"
- **Verifiable** — A script can scan the codebase and report violations
- **Stable** — Unlikely to change in the next 6 months

**Examples:**

```markdown
# Golden Principles

## Shared utilities over hand-rolled helpers
Prefer utility packages in `src/utils/` over duplicating logic.
When the same pattern appears in 3+ places, extract it.

## Typed boundaries, not YOLO probing
Validate data shapes at module boundaries using typed parsers.
Never access nested properties on `unknown` or `any` data
without parsing first.

## Structured logging everywhere
Use `logger.info({ key: value })`, never string interpolation.
Every log entry must include `requestId` for tracing.

## Single source of truth for state
No denormalized data across modules. If two modules need the
same data, one owns it and the other reads from it.

## Tests mirror source structure
`src/foo/bar.ts` → `src/foo/bar.test.ts`. No separate `tests/`
directory. Test file must exist for every non-trivial source file.
```

Store golden principles in `docs/core-beliefs.md` or `docs/golden-principles.md`
and reference them from AGENTS.md.

## Recurring Cleanup Cadence

Replace manual "cleanup Fridays" with automated, continuous maintenance:

### 1. Scan for Violations

Run a scheduled agent task (daily or per-PR) that:

- Checks each golden principle against the codebase
- Identifies files/modules that violate principles
- Counts violations per principle (trending up or down?)
- Outputs a structured report

```markdown
## Scan Report — 2025-12-15

| Principle | Violations | Trend | Worst Offenders |
|---|---|---|---|
| Shared utils over hand-rolled | 7 | ↓ (was 12) | src/worker/retry.ts, src/api/parse.ts |
| Typed boundaries | 3 | → (unchanged) | src/api/webhooks.ts |
| Structured logging | 0 | ✓ clean | — |
```

### 2. Open Targeted Refactoring PRs

For each violation, open a small, focused PR that fixes it. These PRs should be:

- **Atomic** — One principle, one module, one PR
- **Reviewable in under a minute** — Small, obvious changes
- **Auto-mergeable** — If tests pass, merge. No human review needed for mechanical fixes

### 3. Update Quality Scores

Track quality per domain and architectural layer over time:

```markdown
# Quality Score — 2025-12-15

## By Domain
| Domain | Score | Trend | Notes |
|---|---|---|---|
| Auth | A | → | Clean, well-tested |
| Billing | B | ↑ | 2 boundary violations remain |
| Onboarding | C | ↑ | Missing tests for error paths |

## By Layer
| Layer | Score | Trend | Notes |
|---|---|---|---|
| Types | A | → | Zero deps, fully typed |
| Store | B | ↑ | 1 raw SQL query outside store |
| API | B | → | 2 untyped webhook handlers |
| UI | C | ↓ | Growing without test coverage |
```

Scores are simple grades (A-F) based on violation counts, test coverage, and known
gaps. The trend column (↑↓→) is the most important signal — it shows direction,
not just current state.

Store this in `docs/QUALITY_SCORE.md`, versioned in git.

## Tech Debt as Versioned Artifact

Track known technical debt in a structured file, not in Jira/Linear/GitHub Issues:

```markdown
# Tech Debt Tracker

## High Priority
- [ ] `src/api/webhooks.ts` accepts untyped payloads (violates typed-boundaries)
  - Impact: Security risk, brittle error handling
  - Effort: Small (2-3 hours agent work)
  - Blocked by: Nothing

## Medium Priority
- [ ] Retry logic duplicated in `src/worker/` and `src/api/`
  - Impact: Bug fixes need to be applied in two places
  - Effort: Medium (extract to `src/utils/retry.ts`)
  - Blocked by: Need to align retry semantics

## Low Priority / Nice to Have
- [ ] Move from string-based event names to enum
  - Impact: Typos in event names caught at compile time
  - Effort: Medium (large surface area, low risk)
```

This file is the agent's backlog. It can pick up work items, resolve them, and
update the tracker — all within the repo.

## The Progression

Teams typically evolve through three stages:

### Stage 1: Manual Cleanup
Engineers spend dedicated time fixing agent-generated messes. This is necessary
early on but doesn't scale past a few hundred PRs.

### Stage 2: Encoded Principles
Golden principles are documented, referenced from AGENTS.md, and agents generate
cleaner code upfront. Violations still accumulate but more slowly.

### Stage 3: Automated Garbage Collection
Scanning, quality scoring, and refactoring PRs are all automated. Humans review
trends and update principles. The codebase maintains itself.

The goal is to reach Stage 3 as quickly as possible. Each stage builds on the
previous one — you can't automate scans without first knowing what to scan for
(golden principles), and you can't write golden principles without first experiencing
the pain of manual cleanup.

## Key Principles

- **Capture taste once, enforce continuously.** A human notices a bad pattern, encodes
  it as a golden principle, and it applies to every line of code forever after.
- **Small, continuous payments over large, painful bursts.** Daily cleanup PRs > monthly
  refactoring sprints.
- **Track trends, not just snapshots.** A B grade trending upward is better than an A
  grade trending downward.
- **The bad pattern is the one that's most common.** Agents learn from frequency. If 70%
  of your logging uses string interpolation, new code will too. Fix the majority first.
- **Entropy is inevitable; entropy management is a practice, not a project.**
