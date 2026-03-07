---
name: "Technical Writing"
description: "Write clean, terse technical docs — commits, issues, PRDs, specs, and technical communication"
---

# Technical Writing

Write for humans and machines. Every sentence earns its place or gets cut.

## Core Principles

**Lead with the point.** First sentence = the takeaway. Context comes after, if needed.

**One idea per unit.** One point per sentence. One topic per paragraph. One concern per section.

**Concrete over abstract.** Name the thing. Show the example. Skip the preamble.

**Active voice, imperative mood.** "Add retry logic" not "Retry logic should be added" or "Added retry logic."

**No filler words.** Cut: "basically", "simply", "just", "in order to", "it should be noted that", "as mentioned above", "please note that", "going forward". If removing a word doesn't change the meaning, remove it.

**No hedging unless uncertainty is the point.** Say "This will break X" not "This could potentially have an impact on X."

**Prefer short words.** "use" over "utilize", "start" over "initialize", "show" over "indicate", "about" over "approximately."

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

## Format: Inline Code Comments

Only comment *why*, never *what*. The code says what.

Good:
```
// Retry 3x because the payment API returns transient 503s under load
```

Bad:
```
// Call the payment API with retries
```

Don't comment:
```
// Increment counter
count += 1
```

## Format: PR Descriptions

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

## Anti-Patterns

**The Wall of Context.** Three paragraphs of background before the point. Invert it. Point first, context if needed.

**The Passive Report.** "It was determined that the service should be restarted." By whom? Say who did what.

**Weasel Words.** "Some users", "significant impact", "may cause issues." Quantify or be specific.

**Premature Abstraction.** Don't generalize when a concrete example communicates faster.

**The Apology Prefix.** Don't start with "Sorry for the long message" — make the message shorter instead.

**Redundant Structure.** Don't add sections just because the template has them. Empty "Risks: None" sections waste attention. Omit sections that add nothing.

## Editing Checklist

Before publishing, read it once and cut:
1. Sentences that repeat what another sentence already said
2. Adjectives and adverbs that don't change the meaning
3. Throat-clearing openers ("So basically...", "As you may know...")
4. Sections with no actionable content
5. Anything the reader already knows or can infer
