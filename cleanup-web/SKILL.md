---
name: cleanup-web
description: End-of-session cleanup pass for TypeScript, React, and web code. Use this skill whenever the user asks to "clean up", "polish", "tidy", "refactor", or "review" web/frontend work at the end of a coding session, or when they invoke this skill by name. Performs a holistic review of files modified during the session — simplification, type safety, React patterns, CSS modernization, and comment hygiene. Make sure to use this skill anytime the user signals they want to wrap up or finalize TypeScript/React/web work, even if they don't explicitly say "cleanup". Do NOT use for one-off edits, bug fixes, or active feature work.
---

Evaluate the work done in this session and refactor it to a pristine state.

## Disposition

- **Propose, don't apply.** Surface proposed changes with clear reasoning and evidence — show before/after, name the principle that motivates the change, and wait for approval before any edits land.
- **No changes is a valid outcome.** If the code is already clean, say so and stop. Do not invent work to justify the pass.

## Scope

Operate only on files modified during this session. Use `git status`, `git diff`, your task log, or recent tool calls to identify them. Do not touch unrelated code.

If you can't identify the session's modified files with confidence, stop and ask.

## Review skills

Each skill below represents a review lens. Every lens gets its own sub-agent.

| Lens | Skill | Focus |
|------|-------|-------|
| Simplification | `simplify` | Dead code, needless abstractions, single-use helpers, unused params, over-engineered utilities |
| TypeScript | `typescript` | Type soundness, pragmatic generics, discriminated unions over type assertions, `unknown` over `any` |
| Type-driven design | `parse-dont-validate` | Push checks into types; make invalid states unrepresentable; branded types where warranted |
| React effects | `no-use-effect` | Derived state over effects, event handlers over sync effects, `key`-resets over effect-driven resets, `useSyncExternalStore` over manual subscriptions |
| React performance | `vercel-react-best-practices` | Component boundaries, `use client` / `use server` placement, data fetching patterns, bundle impact, memoization |
| CSS | `modern-css` | Native CSS over JS workarounds, logical properties, container queries, modern selectors, no legacy hacks |
| Comment hygiene | `code-comments` | Strip "what" comments and AI narration; keep "why" comments only |

## Approach

Dispatch one sub-agent per review lens, all in parallel. Each sub-agent:

1. **Loads its skill** via the Skill tool — this is required before any review work
2. **Reads the diff** — use `git diff` (and `git diff --cached` if needed) to get the session's changes
3. **Reviews only through its own lens** — do not duplicate another lens's concerns
4. **Returns structured findings** — for each finding: file + location, the proposed change with before/after, the principle behind it, and the trade-off if any. If nothing warrants changing for this lens, say so and return empty findings.

Sub-agent prompt template (adapt the lens name and skill name per row):

> You are reviewing TypeScript/React/web code changes from this session through the **{lens}** lens.
>
> First, load the `{skill}` skill using the Skill tool — read it fully before reviewing.
>
> Then run `git diff` to see what changed. Review those changes exclusively through your lens.
>
> For each finding, return: file path + line range, proposed change (before/after), the principle motivating it, and any trade-off. If nothing needs changing for your lens, say so plainly.
>
> Do not apply changes. Propose only.

After all sub-agents return, **aggregate** their findings:

## Output

Present the aggregated review as a single batch:
- Files reviewed (union of all sub-agent scopes)
- Proposed changes, grouped by file, each tagged with its lens and including before/after and reasoning
- Conflicts between lenses (e.g., one lens wants to add abstraction, another wants to simplify) — flag these for the user to decide
- Anything a sub-agent considered but rejected, with reasoning
- If no sub-agent found anything worth changing, say so plainly and stop

Wait for the user to approve before applying any edits.
