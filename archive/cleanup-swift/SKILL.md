---
name: cleanup-swift
description: End-of-session cleanup pass for Swift code. Use this skill whenever the user asks to "clean up", "polish", "tidy", "refactor", or "review" Swift work at the end of a coding session, or when they invoke this skill by name. Performs a holistic review of session changes — correctness, behavioral test relevance, simplification, type-driven design, macOS conventions, and comment hygiene. Make sure to use this skill anytime the user signals they want to wrap up or finalize Swift work, even if they don't explicitly say "cleanup". Do NOT use for one-off edits, bug fixes, or active feature work.
---

Evaluate the work done in this session and refactor it to a pristine state.

## Disposition

- **Propose, don't apply.** Surface proposed changes with clear reasoning and evidence — show before/after, name the principle that motivates the change, and wait for approval before any edits land.
- **No changes is a valid outcome.** If the code is already clean, say so and stop. Do not invent work to justify the pass.
- **Fail closed.** Never call a review clean when a required lens did not run or the review target is uncertain.

## Freeze the review target

Resolve one authoritative session change set before dispatching subagents. Do not let each subagent independently decide what to review.

Use this order:

1. Use the task log and tool history to identify files written or edited during the session and the commit at which the session began.
2. Include commits created during the session, staged and unstaged changes, and session-created untracked files. A clean working tree does not mean there is nothing to review.
3. If the user is finalizing a branch and the session start is unavailable, use the merge base with the intended base branch through `HEAD`, then confirm the range does not include unrelated work.
4. If scope remains ambiguous, stop and ask.

Use commit hashes, not movable branch names, for committed ranges. If tracked or untracked working-tree content is in scope, materialize one immutable review bundle outside the repository before dispatch: a unified patch, copies of in-scope untracked files, and a path/content-hash manifest. All subagents read that same bundle. Remove it after review.

Print the frozen review manifest before dispatch:

```text
Review target: <commit range plus working-tree state>
Files: <exact paths>
```

Pass this exact target and file list to every subagent. The manifest bounds findings and proposed edits, not read-only context: reviewers may inspect callers, callees, and existing tests outside it, but every finding must anchor to a changed line or newly added file in the manifest.

## Preflight required skills

Verify every skill in the review table is available before dispatch. If any is unavailable, stop and report the cleanup as **incomplete**, naming the missing skill. Do not silently substitute a generic review or treat a failed subagent as an empty finding set.

Track every lens as `completed`, `failed`, or `unavailable`.

## Review skills

Each skill below represents a review lens. Every lens gets its own sub-agent.

| Lens | Skill | Focus |
|------|-------|-------|
| Simplification | `simplify` | Dead code, needless abstractions, unused params, and helpers whose names do not add meaning. Do not inline single-use helpers that clarify call sites or hide non-trivial conditions. |
| Type-driven design | `parse-dont-validate` | Push checks into types; make invalid states unrepresentable |
| Design patterns | `design-patterns-gof` | Patterns only where they earn their weight |
| Platform conventions | `macos-swift-desktop` | Naming, ARC, AppKit/SwiftUI boundaries, threading, main-actor isolation |
| Behavioral tests | `behavioral-testing` | Tests exercise the changed production boundary and observable outcome; post-fix tests fail when the defect is restored |
| Comment hygiene | `code-comments` | Strip "what" comments and AI narration; keep "why" comments only |
| Correctness | `adversarial-review` | Concrete regressions, return-value loss, generic/actor-hop type flow, type erasure, concurrency hazards, swallowed errors, stale callers |

## Approach

### 1. Inventory risk

Before lens review, rank changed production files by risk. Prioritize new or heavily changed code that combines concurrency, generic closures, overloaded APIs, type erasure, serialization, persistence, IPC, external protocols, or irreversible side effects.

If the change exceeds roughly 1,000 changed lines or adds more than five production files, assign concentrated correctness review to each high-risk file or subsystem. Do not imply uniform deep coverage of a large diff.

### 2. Dispatch lenses

Dispatch one subagent per review lens in parallel. Each subagent:

1. **Loads its skill** via the Skill tool — this is required before any review work
2. **Reads the frozen target** — use the exact immutable bundle or commit hashes supplied by the orchestrator
3. **Reviews only through its own lens** — do not duplicate another lens's concerns
4. **Returns structured findings** — for each finding: file + location, the proposed change with before/after, the principle behind it, and the trade-off if any. If nothing warrants changing for this lens, say so and return empty findings.

Sub-agent prompt template (adapt the lens name and skill name per row):

> You are reviewing Swift code changes from this session through the **{lens}** lens.
>
> First, load the `{skill}` skill using the Skill tool — read it fully before reviewing.
>
> Review exactly this frozen target: **{target}**. Findings and proposed edits must anchor to changed lines or newly added files within: **{files}**. You may read callers, callees, and tests outside that list as context. Do not infer a different diff.
>
> For each finding, return: file path + line range, proposed change (before/after), the principle motivating it, and any trade-off. If nothing needs changing for your lens, say so plainly.
>
> Do not apply changes. Propose only.

### 3. Use specialized correctness prompts

The correctness reviewer must preserve `adversarial-review`'s output contract. For each high-risk changed function:

1. State its input, output, and side-effect contract.
2. Determine inferred result types at generic closure and actor-hop boundaries.
3. Trace returned values through overloads, `Any`, serialization, IPC, persistence, and plugin boundaries.
4. For side-effecting APIs, verify the side effect and returned success/error response independently.
5. Give a concrete trigger, severity, confidence, and suggested fix.
6. Attack the finding before reporting it.

Correctness findings use this schema: changed location; violated contract; concrete trigger and observed behavior; severity and confidence; suggested fix and trade-off. Preserve every field during aggregation.

At every consumed result from a multi-statement closure passed to a generic wrapper, determine whether a concrete non-`Void` context constrains the result. If not, verify value-producing paths use explicit returns. When the result crosses a type-erased or external boundary, prefer a concrete expected type that turns accidental `Void` inference into a compile error. Do not apply ordinary closure rules to result builders.

The behavioral-testing reviewer should read changed external entry points and their corresponding tests, then answer:

1. What user- or client-observable behavior changed or failed?
2. Does the test invoke the changed production boundary?
3. Would the test fail if the defect were restored?
4. For side-effecting APIs, does it assert both the side effect and returned response?

"Add more tests" is not a finding without a concrete missing behavior.

### 4. Aggregate

## Output

Present the aggregated review as a single batch:
- Frozen review target and exact files reviewed
- Lens status table (`completed`, `failed`, `unavailable`)
- High-risk files that received concentrated correctness review
- Files reviewed (union of all sub-agent scopes)
- Proposed changes, grouped by file, each tagged with its lens and including before/after and reasoning
- Correctness findings retain their concrete trigger, observed behavior, severity, and confidence
- Conflicts between lenses (e.g., one lens wants to add abstraction, another wants to simplify) — flag these for the user to decide
- Anything a sub-agent considered but rejected, with reasoning
- If a required lens failed or was unavailable, report **incomplete review** and stop before a clean verdict
- If every required lens completed and found nothing worth changing, say so plainly and stop

Wait for the user to approve before applying any edits.
