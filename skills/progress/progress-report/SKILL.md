---
name: progress-report
description: "Report progress against the current plan in plain English: on track or not, done, running, blocked, needs you, next. Use for /progress-report."
disable-model-invocation: true
---

# Progress report

Report where the work stands against its plan, then keep working.

1. Find the plan: the day-plan file, a plan file, the todos, or the ticket. Without one, measure against the goal the user stated.
2. Check live state before you write anything: running jobs, each subagent (working, stuck, or waiting on you), PRs and CI, and the newest results files. Answer any subagent that is waiting on you first.
3. Reply in plain English, under 150 words:
   - One line: on track or not, and why.
   - Done since the last report.
   - Running now, each with an honest ETA or "unknown".
   - Blocked, and what unblocks it.
   - What needs the user, each item with your recommendation.
   - The next step you will take.
4. Continue the work unless the user told you to stop.

**Done when:** every line is checked against live state, not memory.
