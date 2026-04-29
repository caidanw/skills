---
name: cleanup-swift
description: End-of-session cleanup pass for Swift code. Use this skill whenever the user asks to "clean up", "polish", "tidy", "refactor", or "review" Swift work at the end of a coding session, or when they invoke this skill by name. Performs a holistic review of files modified during the session — simplification, type-driven design, macOS conventions, and comment hygiene. Make sure to use this skill anytime the user signals they want to wrap up or finalize Swift work, even if they don't explicitly say "cleanup". Do NOT use for one-off edits, bug fixes, or active feature work.
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
- design-patterns-gof
- macos-swift-desktop
- parse-dont-validate
- ai-code-comments

## Approach

Review each file through each lens. Suggested order:

1. **simplify** — dead code, needless abstractions, single-use helpers, unused params
2. **parse-dont-validate** — push checks into types; make invalid states unrepresentable
3. **design-patterns-gof** — patterns only where they earn their weight
4. **macos-swift-desktop** — platform conventions (naming, ARC, AppKit/SwiftUI boundaries, threading, main-actor isolation)
5. **ai-code-comments** — strip "what" comments and AI narration; keep "why" comments only

For each finding, draft a proposal: file + location, the change, the principle behind it, and the trade-off if any.

## Output

Present the review as a single batch:
- Files reviewed
- Proposed changes, grouped by file, each with before/after and reasoning
- Anything you considered but rejected, with reasoning
- If nothing warrants changing, say so plainly and stop

Wait for the user to approve before applying any edits.
