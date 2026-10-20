---
name: status-update
description: "Write a short update the user can paste to a client, Slack, or a coworker: plain text, in the user's voice. Use for /status-update."
disable-model-invocation: true
---

# Status update

The user will paste this somewhere else under their own name.

1. Pin the audience and the time window. The audience is a client (non-technical), a team channel, or a coworker who needs to act (review, merge). The window defaults to "since the last update"; "since Thursday" means since Thursday.
2. Gather from the record, not memory: merged PRs, ticket changes, results, and what comes next. Check each claim against git, the tracker, or the results files.
3. Write it in the first person singular, in the user's voice: casual and direct, "I shipped…", using "we" only when the user asks.
   - **Client:** outcomes and what they mean for the client, in 3–6 short bullets, with no file names, ticket IDs, or jargon.
   - **Team channel:** impact first, then what changed. Links are fine.
   - **Coworker action:** numbered steps covering what to review, the merge order, and anything to run before or after (such as migrations). One line each, because they can read the PRs themselves.
4. Output plain text, ready to copy in one selection: unquoted, with nothing of yours mixed into it. Use Markdown only when the user asks.
5. Cut it until it is short.

**Done when:** every claim is checked, it reads in the user's voice, and it copies cleanly.
