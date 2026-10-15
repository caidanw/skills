# Artifact Templates

Shapes for the engineering artifacts this skill covers. The sentence rules in `SKILL.md` apply inside every template.

## Artifact Rules

- **First line carries the point.** A commit subject, issue title, or PR title should make sense alone in a list.
- **Imperative mood for actions.** "Add retry logic", not "Added retry logic" or "Retry logic should be added".
- **Testable over vague.** "p95 under 200ms", not "fast". "Fails on empty input", not "has issues".
- **Omit empty sections.** A template is a checklist, not a form to fill. No "Risks: None".

## Format: Git Commits

Structure:
```
<type>: <what changed>

<why it changed — optional, only if non-obvious>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

Rules:
- Subject line under 72 characters
- Imperative mood: "Add X" not "Added X" or "Adds X"
- No period at end of subject
- Body explains *why*, not *what* — the diff shows what
- Reference issue numbers when relevant: `Fixes #42`

Good:
```
feat: add rate limiting to /api/upload

Prevents abuse from automated clients. Limits to 100 req/min
per API key. Returns 429 with Retry-After header.

Fixes #187
```

Bad:
```
Updated the upload endpoint to add some rate limiting functionality
so that we can prevent potential abuse issues going forward
```

## Format: GitHub Issues

### Bug Reports

```markdown
## Problem
<What's broken — one sentence>

## Steps to Reproduce
1. <Exact steps>
2. <No ambiguity>

## Expected
<What should happen>

## Actual
<What happens instead>

## Context
- Version/commit: <hash or version>
- Environment: <OS, browser, runtime>
- Logs/screenshots: <if relevant>
```

### Feature Requests

```markdown
## Problem
<What user need is unmet — not the solution, the problem>

## Proposed Solution
<How to solve it — be specific>

## Alternatives Considered
<What else you evaluated and why it lost>

## Scope
<What's in, what's explicitly out>
```

## Format: PRD (Product Requirements Document)

```markdown
# <Feature Name>

## Problem
<Who has this problem. What they can't do. Why it matters now.>

## Solution
<What we're building. 2-3 sentences max.>

## Requirements

### Must Have
- <Requirement — testable, unambiguous>
- <Each one starts with a verb>

### Nice to Have
- <Lower priority items>

### Out of Scope
- <Explicitly excluded to prevent scope creep>

## Success Criteria
- <Measurable outcome>
- <How we know this worked>

## Technical Notes
<Constraints, dependencies, migration concerns — only if relevant>

## Open Questions
- <Unresolved decisions, with owners and deadlines>
```

Rules:
- Requirements are testable. "Fast" is not a requirement. "Page loads in < 200ms at p95" is.
- Each requirement starts with a verb: "Support", "Display", "Validate", "Allow".
- Success criteria are measurable. If you can't measure it, sharpen it.
- Open questions have owners. Unowned questions don't get answered.

## Format: Technical Specs / Design Docs

```markdown
# <Title>

## Context
<Why this doc exists. What decision or system it describes. 2-3 sentences.>

## Design

### Architecture
<How it works. Diagrams welcome, walls of text not.>

### Data Model
<Schema changes, new entities, relationships.>

### API
<Endpoints, contracts, examples.>

## Tradeoffs
<What you chose and what you gave up. Be honest about costs.>

## Risks
<What could go wrong. What's the mitigation.>
```

## Format: PR Descriptions

If the repo squash-merges, the PR title becomes the commit on `main`. Write it like a commit subject that describes the outcome, never `WIP`, `address comments`, or `update branch`.

```markdown
## What
<One sentence — what this PR does>

## Why
<Motivation — link to issue if applicable>

## How
<Brief summary of approach — not a line-by-line walkthrough>

## Testing
<How you verified this works>
```

## Editing Checklist

Before publishing, read it once and cut:
1. Sentences that repeat what another sentence already said
2. Adjectives and adverbs that don't change the meaning
3. Throat-clearing openers ("So basically...", "As you may know...")
4. Sections with no actionable content
5. Anything the reader already knows or can infer
