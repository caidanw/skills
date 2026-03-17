---
name: code-comments
description: >-
  Write high-signal code comments for humans and coding agents.
  Use when adding inline comments, docstrings, API comments, or local rationale near code.
  Triggers on: "write better comments", "comment this", "document why",
  "agent-friendly comments", "explain this code with comments", "docstring".
---

# Code Comments

Write code so the structure explains the `what`. Write comments so future humans and agents understand the `why`, `why not`, `what must stay true`, and `what already happened here`.

## Core Rule

Use this order:

```text
1. Rename, extract, reorder, or delete code until the intent is obvious
2. Add a comment only when the missing context cannot live in code
3. Put the shortest useful comment as close as possible to the code
4. Keep the comment short, local, and durable
```

Good comments reduce wrong edits. Great comments stop humans and agents from repeating old mistakes.

## The Comment Test

Before writing a comment, ask:

```text
Can clearer code remove the need for this comment?
  Yes -> refactor first
  No  -> comment the missing context

Will this comment still be true after a small refactor?
  No  -> move the detail into code or delete it
  Yes -> keep it

Does this comment tell the reader something the code cannot?
  No  -> delete it
  Yes -> keep it
```

## What To Comment

Comments earn their keep when they capture one of these:

### Intent

Why this code exists.

```ts
// Normalize partner payloads here so the rest of the pipeline can assume
// internal field names and avoid partner-specific branches.
```

### Constraint

A rule the code must respect because of product, legal, protocol, or platform limits.

```ts
// Keep card brand names verbatim for PCI audit exports.
// Product copy uses friendly labels elsewhere, but not in this file.
```

### Invariant

A property that must remain true across future changes.

```ts
// INVARIANT: cache keys must include tenantId.
// Cross-tenant collisions become data leaks, not cache misses.
```

### Tradeoff

Why a less-obvious implementation beat the simpler-looking one.

```ts
// We batch writes every 250ms to cut lock contention.
// Immediate writes looked simpler but doubled p95 latency in production.
```

### History

What already happened that future editors should know.

```ts
// Keep the retry delay capped at 5s.
// A longer backoff caused checkout sessions to expire during incident 2024-11-18.
```

### Warning

What not to "simplify" and why.

```ts
// Do not collapse this into a single upsert.
// Duplicate webhooks can arrive out of order; the two-step write is intentional.
```

### Reference

Where the deeper story lives.

```ts
// CSV escaping follows RFC 4180 with an Excel-specific quoting carve-out.
```

## What Not To Comment

Do not comment things that should live in code.

Bad:

```ts
// Increment retry count
retryCount += 1

// Get user by id
const user = await getUserById(userId)
```

Better:

```ts
retryCount += 1
const user = await getUserById(userId)
```

Bad:

```ts
// Build request
const req = buildPaymentRequest(order)
```

Better:

```ts
const paymentRequest = buildPaymentRequest(order)
```

If a comment only translates weak names into better English, fix the names.

## Write For Three Audiences

Every high-signal comment should help all three:

1. Your future self scanning the file at speed
2. A teammate without the original decision context
3. A coding agent proposing edits from local evidence only

That means:

- Prefer explicit nouns over vague pronouns
- Name the thing that would break
- State the consequence, not just the preference
- Use issue or incident ids when they exist
- Keep comments local and durable

## Inline Comment Templates

Use these templates directly. Replace brackets with concrete facts.

### Decision Comment

```ts
// Use [approach] because [constraint/tradeoff].
// [Alternative] looked simpler but failed on [case]. See [issue/incident].
```

Example:

```ts
// Use a stable sort because invoice lines with equal priority must keep upload order.
// Hash bucketing looked simpler but changed exported totals. See issue #214.
```

### Invariant Comment

```ts
// INVARIANT: [property that must remain true].
// If this changes, [bad outcome].
```

Example:

```ts
// INVARIANT: every audit event must include actorId, even for system actions.
// If this changes, backfills and incident review lose causality.
```

### Compatibility Comment

```ts
// Keep [odd code] for [browser/vendor/legacy system] compatibility.
// Remove only after [condition].
```

Example:

```ts
// Keep CRLF line endings for the bank import tool.
// Remove only after finance confirms parser v3 is live in all regions.
```

### Incident Breadcrumb

```ts
// Added after [incident/bug].
// This guards against [failure mode] when [trigger].
```

Example:

```ts
// Added after INC-482.
// This guards against duplicate shipment creation when the carrier webhook retries.
```

### Temporary Work Comment

```ts
// TEMP: [workaround].
// Remove after [specific event/version/date owner], not "later".
```

Example:

```ts
// TEMP: skip image optimization for SVG uploads.
// Remove after `media-service` 2.4 lands and backfill job completes.
```

### Non-Obvious Example Comment

```ts
// Example: [input] -> [output].
// This matters because [surprising rule].
```

Example:

```ts
// Example: " ACME-01 " -> "acme-01".
// This matters because partner ids are case-insensitive but whitespace-significant upstream.
```

## Docstrings And API Comments

Docstrings should describe contract, side effects, and sharp edges. Do not restate the implementation.

Bad:

```py
def sync_users():
    """Sync users from the API."""
```

Better:

```py
def sync_users():
    """Pull active users from the billing API and upsert local records.

    Side effects:
    - writes `users` and `subscriptions`
    - emits `user_synced` events

    Safe to retry. Not safe to run concurrently for the same account.
    """
```

Prefer this structure when the boundary matters:

```text
What it guarantees
What it mutates or emits
What callers must provide
When it is unsafe or expensive
```

## Anti-Patterns

### Narration

```ts
// Loop through items
for (const item of items) {
```

The code already says this.

### Name Translation

```ts
// User's email address
const eml = user.email
```

Rename `eml` or delete the comment.

### Vague Intent

```ts
// Handle edge case
```

Name the edge case and consequence.

### Fake Temporariness

```ts
// TEMP: remove later
```

This never gets removed. Say when, after what, and by whom if needed.

### Ghost History

```ts
// Weird bug fix
```

Which bug? Under what condition? What breaks if removed?

### Comment Drift

```ts
// Returns a list sorted by createdAt ascending
return users.sort((a, b) => b.createdAt - a.createdAt)
```

Stale comments are worse than no comments.

### Essay Comments

Do not bury the point in five lines of setup. Lead with the rule or decision, then add one sentence of context if needed.

## Review Checklist

Before keeping a comment, check all of these:

```text
[] Does the code already say this?
[] Does the comment explain why, constraint, invariant, tradeoff, history, or warning?
[] Is the comment specific about what breaks or matters?
[] Will the comment likely survive a routine refactor?
[] Should any extra detail be cut because the local comment is already enough?
[] Did I include a reference if the decision came from an issue, incident, or RFC?
[] Would this comment stop a smart agent from making the wrong cleanup?
```

If the answer to the last question is no, the comment may not be pulling its weight.

## Editing Workflow

When modifying code:

```text
1. Delete comments made obsolete by your change
2. Rewrite comments whose scope changed
3. Add a short decision comment if the new code looks "weird" for a reason
4. Leave the file with fewer, better comments than you found it
```

## Default Style

- Use short sentences
- Lead with the decision or warning
- Name concrete systems, fields, incidents, or documents
- Prefer `Do not ... because ...` over soft phrasing
- Prefer one strong comment over three weak ones
- Avoid jokes, filler, and private context nobody else can recover

The goal is not more comments. The goal is better evidence for future readers and future agents.
