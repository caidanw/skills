---
name: typescript-refactoring
description: >-
  Systematically refactor TypeScript codebases for readability, type safety,
  and AI-friendliness. Use when asked to "refactor this", "clean up this code",
  "make this codebase better", "improve code quality", or when inheriting a
  messy TypeScript project. Covers assessment, prioritization, and safe
  incremental transformation.
  Triggers on: "refactor", "clean up", "improve this code", "code quality",
  "make this readable", "technical debt", "code review", "modernize".
globs: ["*.ts", "*.tsx", "*.mts", "*.cts"]
---

# TypeScript Refactoring

Refactoring is changing structure without changing behavior. Assess before changing. Small steps, verified continuously. The `typescript` skill defines what good TypeScript looks like — this skill defines how to get there from messy code.

## 1. The Iron Rules

These are non-negotiable. Violating them turns refactoring into "changing stuff and hoping."

1. **Never change behavior and structure in the same commit.** Refactoring commits change structure only. Feature commits change behavior only. Mixing them makes rollback impossible and code review meaningless.

2. **Never refactor without tests.** If tests don't exist, write characterization tests first — tests that capture current behavior, even if that behavior is wrong. Fix the behavior later, separately.

3. **One smell at a time, codebase-wide.** Fix all `any` types, then all long functions, then all enums. Don't fix everything in one file — fix one thing across all files. This produces consistent, reviewable diffs.

4. **Every step must be independently verifiable.** Tests pass after each commit. If a refactoring breaks tests, it's too big — break it into smaller steps.

5. **Prefer boring, obvious transformations.** Rename a variable. Extract a function. Inline a pointless wrapper. These are safe, reviewable, and reversible. Clever restructuring is risky.

## 2. Assessment: Read Before You Cut

Before changing anything, understand what you have. Present findings to the user before starting work.

**Run the basics:**
```bash
# Does it build? Does it pass?
npm run build
npm test

# What's the shape of the codebase?
find src -name '*.ts' -o -name '*.tsx' | wc -l          # file count
find src -name '*.ts' -o -name '*.tsx' -exec wc -l {} + # line counts
```

**Identify the hot paths** — code that changes most often has the highest refactoring ROI:
```bash
# Most frequently changed files in the last 6 months
git log --since="6 months ago" --pretty=format: --name-only -- '*.ts' '*.tsx' \
  | sort | uniq -c | sort -rn | head -20
```

**Categorize what you find:**
- Read entry points and trace the dependency graph
- Note the biggest files, deepest nesting, widest functions
- Scan for `any`, `enum`, `namespace`, barrel files, dead code
- Check tsconfig strictness settings — are `strict`, `noUncheckedIndexedAccess` enabled?
- Look at test coverage — which areas are safe to touch?

**Present your assessment:**
```
## Assessment Summary
- X files, Y total lines
- Build: passing/failing
- Tests: X passing, Y failing, Z% coverage
- Strictness: strict=true/false, noUncheckedIndexedAccess=true/false
- Top smells: [list with counts]
- Hot paths: [most-changed files]
- Recommended priority: [what to fix first and why]
- Estimated scope: [1-hour cleanup / multi-day migration / needs discussion]
```

## 3. Priority Order

Fix in this order. Each level makes the next level easier and safer.

### Level 1: Type Safety
Eliminate `any`, add missing return types, enable strict flags. This is the highest-leverage change — the compiler catches bugs for you after this.

### Level 2: Dead Code
Remove unused imports, exports, unreachable branches, commented-out code. Less code = less to read, less to maintain, fewer false signals for AI agents.

### Level 3: Naming
Rename unclear variables, functions, and files to reveal intent. This is the single biggest readability win. `data` → `userProfile`, `res` → `apiResponse`, `handle` → `handlePaymentWebhook`.

### Level 4: Structure
Extract functions from long bodies. Split God files. Flatten deep nesting with early returns and guard clauses. Target: functions under 20 lines, files under 300 lines, nesting under 3 levels.

### Level 5: Patterns
Migrate anti-patterns to modern TypeScript: enums → union types, classes → factory functions (where appropriate), boolean soup → discriminated unions, barrel file chains → direct imports.

### Level 6: API Boundaries
Add branded types, parse at boundaries, tighten function signatures. This is the final polish — making the type system enforce domain rules.

For specific smells and how to detect them, see [references/smell-catalog.md](references/smell-catalog.md).
For step-by-step transformation recipes, see [references/transformation-playbook.md](references/transformation-playbook.md).

## 4. Safe Transformation Workflow

For each refactoring, follow this loop:

```
1. Verify tests pass                    (baseline)
2. Make ONE structural change           (extract, rename, move, inline)
3. Verify tests still pass              (behavior preserved)
4. Commit with descriptive message      (checkpoint)
5. Repeat
```

**For risky changes**, use the strangler fig pattern:
1. Create new implementation alongside old
2. Route one caller to the new implementation
3. Verify behavior matches
4. Migrate remaining callers incrementally
5. Delete old implementation when all callers migrated

**For large migrations** (e.g., enabling `strict: true` on a non-strict codebase):
1. Enable the flag
2. Fix errors file-by-file, starting with leaf modules (no dependents)
3. Work inward toward the core
4. Commit after each file or small group of files

**Commit messages during refactoring:**
```
refactor: rename UserData → UserProfile across auth module
refactor: extract calculateDiscount from processOrder
refactor: eliminate any in api/client.ts
refactor: migrate Status enum to union type
chore: remove 12 unused imports in src/utils/
```

## 5. What Makes Code AI-Friendly

AI agents read code to understand it, then generate new code that fits. These patterns directly improve both capabilities:

**Explicit types reduce guessing.** When a function has `): Promise<User | null>`, the AI knows exactly what it returns. Without it, the AI must infer — and may infer wrong.

**Descriptive names communicate intent.** AI agents infer purpose from names more than humans realize. `getUserById` tells the AI everything. `get` tells it nothing. Rename aggressively.

**Small functions fit in context windows.** AI agents have limited context. A 200-line function forces the AI to hold all of it in memory. Five 20-line functions let the AI focus on the relevant one.

**Flat control flow is easier to trace.** Deeply nested `if/else/try/catch` blocks confuse AI agents the same way they confuse humans. Early returns, guard clauses, and extracted conditions keep the happy path obvious.

**Consistent patterns teach by example.** If every API handler follows the same shape — validate input, call service, return response — the AI learns the pattern and replicates it correctly. Inconsistency forces the AI to guess which pattern to follow.

**Types replace comments.** A type like `EmailAddress` (branded type) or `AsyncState<T>` (discriminated union) communicates more than any comment. Types are verified by the compiler; comments rot.

**Strict tsconfig catches AI mistakes.** Enable `strict: true` and `noUncheckedIndexedAccess: true`. These flags catch the most common AI-generated bugs: unsafe index access, missing null checks, implicit `any`.

**Colocated code reduces jumping.** When types, utilities, and components live in the same directory, AI agents find them faster. Scattered code across distant directories increases the chance the AI misses context.

## 6. What NOT to Do While Refactoring

- **Don't "big bang" rewrite.** It always takes 3x longer, loses domain knowledge, and can't be deployed incrementally. Use strangler fig instead.
- **Don't abstract prematurely.** Wait for the 3rd use case before extracting a shared abstraction. Two similar functions are fine — a wrong abstraction is worse than duplication (AHA principle).
- **Don't refactor and add features simultaneously.** Separate commits, separate PRs if possible. Mixed diffs are unreviewable.
- **Don't "improve" code you're not asked to touch.** Scope creep during refactoring creates unexpected breakage. Fix what's in scope, note what's out of scope.
- **Don't optimize performance without measurements.** Refactoring for readability is always justified. Refactoring for performance requires profiling evidence.
- **Don't fight the existing architecture.** If the codebase uses classes everywhere, don't convert everything to factories in one pass. Propose a migration plan and get buy-in first.

## Companion Skills

- **`typescript`** — the target state. What good TypeScript looks like. Reference this for specific patterns (discriminated unions, branded types, factory functions, etc.)
- **`karpathy-guidelines`** — behavioral constraints. Think before coding, simplicity first, surgical changes, goal-driven execution.
- **`agent-first-repo`** — repo-level improvements. AGENTS.md, ARCHITECTURE.md, documentation structure, mechanical enforcement of architecture.
- **`systematic-debugging`** — when refactoring reveals bugs. Follow root-cause investigation, don't patch symptoms.

For the full smell catalog, see [references/smell-catalog.md](references/smell-catalog.md).
For step-by-step transformation recipes, see [references/transformation-playbook.md](references/transformation-playbook.md).
