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

## Load these skills before reviewing

- simplify
- typescript
- parse-dont-validate
- no-use-effect
- vercel-react-best-practices
- modern-css
- code-comments

## Approach

Review each file through each lens. Suggested order:

1. **simplify** — dead code, needless abstractions, single-use helpers, unused params, over-engineered utilities
2. **typescript** — type soundness, pragmatic generics, discriminated unions over type assertions, `unknown` over `any`
3. **parse-dont-validate** — push checks into types; make invalid states unrepresentable; branded types where warranted
4. **no-use-effect** — derived state over effects, event handlers over sync effects, `key`-resets over effect-driven resets, `useSyncExternalStore` over manual subscriptions
5. **vercel-react-best-practices** — component boundaries, `use client` / `use server` placement, data fetching patterns, bundle impact, memoization
6. **modern-css** — native CSS over JS workarounds, logical properties, container queries, modern selectors, no legacy hacks
7. **code-comments** — strip "what" comments and AI narration; keep "why" comments only

For each finding, draft a proposal: file + location, the change, the principle behind it, and the trade-off if any.

## Output

Present the review as a single batch:
- Files reviewed
- Proposed changes, grouped by file, each with before/after and reasoning
- Anything you considered but rejected, with reasoning
- If nothing warrants changing, say so plainly and stop

Wait for the user to approve before applying any edits.
