---
name: adversarial-review
description: Adversarially hunt for correctness bugs and regressions in a change set. Use when reviewing a diff before finalizing, during a cleanup pass, or when asked to find bugs, pressure-test, or stress-test recently modified code. Triggers on: "find bugs", "what could break", "review for correctness", "did I break anything", "hunt regressions", "adversarial review", "pressure-test this change".
---

# Adversarial Review

Assume the change is wrong until a concrete input proves it right. Hunt correctness bugs the change introduced — not style, not security. One finding you can trigger beats ten you cannot.

## Stance

- Default to distrust. The diff is guilty until a named input clears it.
- No credit for good intent, partial fixes, or "probably fine."
- Happy-path-only is a defect. If code only works on the example input, that is the finding.
- A specific attack angle ("what input makes this throw?") finds bugs. "Review this code" produces polite nothing.

## Scope

Review the change, not the codebase.

- Read the diff's added and changed lines (`git diff`). Every finding ties to a changed line.
- Trace the blast radius: for each changed signature, return shape, nullability, or unit, read its callers. A rename or a newly-nullable return breaks stale callers the diff never shows — the regression pure-diff review structurally misses.
- Hand off, do not duplicate. Style → `simplify`. Comment intent → `code-comments`. Type design → `parse-dont-validate`. Security → `security-review`. Framework idioms → `typescript` / `no-use-effect` / `macos-swift-desktop`.

This is read-only. Propose fixes; do not apply them, and do not touch code outside the change.

## What to hunt

| Bug class | The tell |
|---|---|
| Null / optional | A value from an API, map lookup, regex match, or DB row is dereferenced without a guard |
| Boundary / off-by-one | Index math, slice bounds, `<` vs `<=`, empty or single-element input |
| Swallowed error | Empty catch, catch-log-continue, ignored error/`Result` return, un-awaited rejection |
| Happy-path gap | Works on the demo input; empty / zero / negative / huge / missing-field / dependency-down untested |
| Race / ordering | Shared mutable state, check-then-act, an `await` between a read and its write |
| State mutation / aliasing | Mutates a passed-in object, array, or default arg the caller still holds |
| Async / await | A promise used as its value, a forgotten `await`, `async` inside `forEach`, sequential-vs-parallel slip |
| Type coercion | `==` vs `===`, truthy `0` / `""` / `[]`, implicit string↔number, `NaN` |
| Resource leak | Acquire (file, socket, lock, listener, subscription) with no release on every path — especially the error path |
| Inverted logic | Flipped boolean, wrong operator, bad default, De Morgan slip — plausible, but takes the wrong branch |
| Contract mismatch | Signature / units / nullability / return shape changed but not all callers; or a call with wrong or hallucinated args |
| Partial change | One branch updated but not its twin; a flag without the gated code; a migration without its reader; leftover TODO |

Weight the hunt: fresh, often agent-written code skews to happy-path gaps, missing null and edge guards, swallowed errors, mismatched or hallucinated APIs, and half-finished refactors. Look there first.

## Technique

For each changed function:

1. State its contract in one line before reading the body — inputs, output, side effects. Then check the body actually delivers it.
2. Assume every variable can be null and every external call can fail. Find the first line that does not survive that assumption.
3. Construct one concrete failing input and trace it line by line to the suspect spot. Verify it actually reaches that line — not a plausible neighbor.
4. Ask "if I deleted this change, what breaks?" — tests whether it is necessary and what it regresses.

## Report only what you can trigger

The gate that keeps findings high-signal:

- Name the input or path that triggers the bug. Cannot name it → do not report it.
- Do not speculate about breakage you cannot trace to a specific code path.
- Read the surrounding context first — callers, guards, sanitizers. A line that looks unsafe alone is often safe in context.
- Tag each finding with severity and a confidence: high / medium / low.
- Exception: high-impact bugs (data loss, corruption, crash on common input) — report even at lower confidence, and state what is uncertain.
- Prefer one strong finding over five weak ones. Do not pad.

## Self-verification

Before surfacing anything, attack your own findings. For each, try to prove it false: re-read the trigger path, confirm the guard you assumed was missing really is missing, confirm the input really reaches the line. Drop anything you cannot defend.

This pass is what separates real findings from plausible noise. Do not skip it.

## Output

For each surviving finding:

- Location — file and line in the diff
- The bug — one sentence
- The trigger — the concrete input or sequence that makes it fail
- Severity + confidence
- Suggested fix — propose, do not apply

If the change holds up under attack, say so plainly. Finding nothing is a valid, honest result — do not invent bugs to look thorough.
