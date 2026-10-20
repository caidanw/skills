---
name: update-client
description: "Write a short, non-technical update the user can paste to their client: plain text, in the user's voice. Use for /update-client."
disable-model-invocation: true
---

# Update client

The user will paste this to a non-technical client under their own name.

1. Pin the time window. It defaults to "since the last update"; "since Thursday" means since Thursday.
2. Gather from the record, not memory: merged PRs, ticket changes, results, and what comes next. Check each claim against git, the tracker, or the results files.
3. Write it in the first person singular, in the user's voice: casual and direct, "I shipped…", using "we" only when the user asks.
4. Say what changed for the client and what it means for them, in 3–6 short bullets, then one line on what comes next. Leave out file names, ticket IDs, PR numbers, and jargon. Describe a technical change by its effect ("pages load in a second instead of timing out").
5. Output plain text, ready to copy in one selection: unquoted, with nothing of yours mixed into it.
6. Cut it until it is short.

**Done when:** every claim is checked, a non-technical reader understands every line, and it copies cleanly.
