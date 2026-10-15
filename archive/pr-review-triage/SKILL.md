---
name: pr-review-triage
description: Pull PR review comments and triage them — separate substantive feedback from bikeshedding, stale comments, misreads, AI slop, and other noise. Use this skill whenever the user asks to "review my PR comments", "triage feedback", "go through my PR", or wants help deciding what to address vs push back on. Make sure to use this skill anytime the user mentions PR comments or code review feedback, even if they don't explicitly say "triage". Pulls comments via the `gh` CLI, classifies each, and proposes an action with a draft response. Do NOT use for writing PR descriptions, reviewing someone else's PR, or applying the changes — this skill triages and drafts only.
---

Pull review comments on a PR and triage each one. Figure out what's substantive, what's bikeshedding, and what's noise.

## Get the comments

Default source: GitHub via the `gh` CLI.

If the user gives a PR number or URL, use it. Otherwise list their open PRs and ask which one.

```bash
gh pr view <number-or-url> --json reviews,reviewThreads,comments
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

Pull both review-level comments and inline thread comments. For each, capture: author, body, file + line (if inline), thread resolution status, and the commit SHA the comment was made against. Where possible, note whether the code at that line has changed since the comment was posted.

## Classify each comment

Apply labels. Multiple can apply.

**Substantive**
- `bug` — real correctness, security, or data-integrity issue
- `design` — concrete maintainability/readability point with specific reasoning
- `domain` — surfaces context the author may be missing (constraint, prior decision, downstream impact)

**Noise**
- `bikeshed` — style/naming/formatting preference, especially where a linter or formatter would settle it
- `stale` — code at that line has changed since the comment; may no longer apply
- `misread` — reviewer misunderstood what the code does
- `vague` — "feels off", "have you considered", no concrete issue
- `ai-slop` — pattern-matched suggestion that ignores context (often verbose, hedged, generic, or restates the diff)
- `scope-creep` — asks for changes outside the PR's stated goal
- `unfounded` — performance/security concern with no measurement or threat model

A comment is noise unless it survives this question: *if I made the change they're asking for, would the code be meaningfully better, or just different?*

The classification is a draft, not a verdict. The user knows their reviewer, codebase, and team norms — defer to their judgment when they push back.

## Triage action

For each comment, recommend one:
- **Address** — make the change
- **Push back** — explain why not
- **Defer** — file an issue, out of scope for this PR
- **Clarify** — ask the reviewer for the missing context (concrete example, threat model, measurement)
- **Ignore** — already resolved or stale; mark resolved without responding

## Output

Per comment:
- Reviewer + location (`file:line` or "review-level")
- Comment quote (trimmed if long)
- Labels
- Recommended action + one-line reasoning
- If push back or clarify: draft response — direct, no apologetic preamble, no "great point!", no "you're absolutely right"

Group by recommended action so the user can work Address items first, then send drafts.

End with a tally: e.g. "12 comments → 4 address, 5 push back, 2 defer, 1 ignore."

Do not apply code changes or post responses. This skill triages and drafts only.
