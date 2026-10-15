# Attack the Premise

When two or more fixes that share one premise have failed the same check, suspect the premise, not the fixes.

**Why:** Each failure under a shared premise is evidence against the premise. Another fix that assumes it spends the next attempt on the same wrong bet.

**Pattern:**
- **Write the premise down.** The premise is the one sentence every failed fix assumed: "the cache is stale", "the query is the slow part", "worker 3 is overloaded because it gets more jobs".
- **Measure the premise before the next fix.** Collect the evidence that would show it true or false, broken down by the parts involved: per request, per worker, per file, per user, per run. Write the measurement as a rerunnable script per [Build the Lever](build-the-lever.md).
- **Read the distribution.** If the problem is spread evenly, the premise is probably wrong. If the same few parts hold most of it on every run, something assigns them that role. Find what assigns the role. That assignment is the next "why" per [Fix Root Causes](fix-root-causes.md).
- **Remove the cause instead of compensating for it**, per the [Laziness Protocol](laziness-protocol.md). Change what assigns the role so no part holds it on every run. Retries, extra capacity, a periodic rebalance, or a special-case branch leave the cause in place and add work on every run.

**Stop:**
- Do not start the next fix before the premise is written down and the measurement exists.
- If the measurement contradicts the premise, drop the premise, keep the measurement as evidence, and look for the cause elsewhere.

This principle is distinct from [Redesign from First Principles](redesign-from-first-principles.md), which rebuilds a design around a new requirement. It questions a fact the current design assumes.
