---
name: day-plan
description: "Plan the day from open tickets, PRs, and the last day plan into a day-plan file, or wrap up the day and set up tomorrow. Use for /day-plan."
disable-model-invocation: true
---

# Day plan

Two branches: start of day (the default) and wrap-up (the user is ending the day).

## Start of day

1. Find the time available. Plan around parallel agent work, not human-day estimates.
2. Gather: the last day-plan file, open tickets under the active parent ticket, open PRs with their CI and merge state, running jobs, and whatever the last session left unfinished.
3. Propose tracks in order of value toward the stated goal. Give each an exit condition, mark which can run in parallel and what needs the user, and flag anything worth dropping.
4. Once the user agrees, write `day-plan-YYYY-MM-DD.md` in the project root and mirror its main points into todos. When another agent already owns a day plan there, prefix yours (for example `experiments-day-plan-YYYY-MM-DD.md`).
5. Re-read the file after every compaction and whenever the user asks where things stand.

## Wrap-up

1. List what got done today (merged PRs, results, decisions) and what is still open, from the file and live state.
2. Post the plan for tomorrow to the tracker.
3. Write tomorrow's starting point into the day-plan file, so the next session can start cold.
4. Tell the user what can keep running safely while they are away, and what to stop.

**Done when:** the file is saved and the user has seen the plan in a few lines.
