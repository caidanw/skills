---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Find this conversation's transcript before fanning out. Read only this conversation's file, never other projects' sessions, which are private and unrelated.

- **pi:** `$PI_SESSION_FILE`.
- **Claude Code:** the newest `~/.claude/projects/-Users-you-proj/*.jsonl` for `/Users/you/proj` whose first user message matches this conversation's opening prompt.
- **Codex:** the newest `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` whose first record names this working directory and whose first user message matches.

If none matches, or your harness keeps no transcript file, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

Spawn three subagents at once when your harness has them (pi: the `subagent` tool; Claude Code: the Task tool). Give them the same tool access you have, MCP servers included, since they look up the tickets, chat threads, and traces the transcript references. Without subagents, run the three lenses yourself one at a time, each from its template, before you synthesize.

| Lens | Model | Prompt template |
|---|---|---|
| Judgment | your strongest model | `references/judgment-reviewer.md` |
| Tooling | a fast model | `references/tooling-reviewer.md` |
| Divergent | your strongest model, a different family from Judgment if available | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in their final response.

## 3. Synthesize

One more subagent on your strongest model, with the same tool access so it can spot-verify citations. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. A check that fails beats an instruction an agent can skip.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to the team's backlog tracker without waiting. With no tracker available, list them in the summary instead. Only the Accepted list waits for approval.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): follow the **writing-for-agents** skill if installed and its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): rewrite the description per the same guide, then check it triggers on the prompt that missed.
- `new skill: <kebab-name>`: create it with the same guide. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
