---
name: agents-md
description: >-
  Write effective AGENTS.md files that give coding agents only the context they cannot infer
  from the repository. Use when creating a new AGENTS.md, improving or trimming an existing one,
  setting up a repo for AI coding agents, or onboarding agents to a codebase. Triggers on:
  "write AGENTS.md", "create AGENTS.md", "agent instructions", "set up repo for agents",
  "configure coding agent", "onboard agent to codebase", "agent context file", "CLAUDE.md".
---

# Writing Effective AGENTS.md Files

AGENTS.md is loaded into every agent session in the repo (format: https://agents.md).
Every line costs tokens on every task, and agents follow what it says. So it should hold only what an agent cannot work out by reading the code, and it must stay true.

## Evidence

An ETH Zurich study (Gloaguen et al., 2026, arXiv:2602.11988) tested context files across several agents and models:

- Context files did not generally raise task success and raised inference cost by over 20%.
- This held for both LLM-generated and developer-written files.
- Agents followed the instructions well, but **repository overviews did not help**.
- Context files were useful for **non-standard practices** the agent would otherwise get wrong.

Treat this as the design rule: include what is non-standard, and leave out what is discoverable.

## Core Rule: Only Non-Inferable Context

Before adding a line, ask: "Would a capable agent get this wrong after reading the code, config, and CI?" If not, cut it.

| Include | Leave out |
|---|---|
| Commands that differ from the obvious (`bun` not `npm`, `just test`, a Nix shell, codegen steps) | `npm install` / `npm test` when `package.json` already says so |
| How to run a single test or a fast subset | A directory tour or file-by-file overview |
| Project conventions that break the usual default | Language basics and general best practices |
| Traps: generated files, slow or flaky suites, required env vars, services that must be running | Anything a linter, formatter, or type checker already enforces |
| Architecture rules the code does not make obvious ("workers never import API code") | How a module works internally (belongs in code comments or `ARCHITECTURE.md`) |
| Hard guardrails: what never to do, what to ask about first | README content: project pitch, badges, end-user install |
| Pointers to deeper docs, with when to read them | Content copied from those docs |

## Sections

Use only the sections that have content. A five-line AGENTS.md is fine.

### Commands

Only the non-obvious ones, especially single-test and codegen commands.

```markdown
## Commands
- Package manager is bun. Do not use npm or pnpm.
- Single test: `bun test path/to/file.test.ts`
- After editing `schema.prisma`: `bun run db:generate` (types are stale until you do)
- Integration tests need `docker compose up -d db` first
```

### Conventions That Break Defaults

```markdown
## Conventions
- Errors: return `Result<T, E>` from `src/lib/result.ts`; do not throw in domain code
- Logging: use `log` from `src/lib/logger.ts`, never `console.*` (stripped in prod builds)
- DB columns are snake_case; the ORM maps them, so never hand-write camelCase SQL
```

### Boundaries

```markdown
## Boundaries
- `src/api/` never touches the database directly; go through `src/store/`
- Never edit files under `src/generated/`; run `bun run codegen`
- Never commit secrets or run destructive git commands (force push, hard reset) without asking
- Ask first: new dependencies, migrations, cross-package refactors
```

### Pointers

```markdown
## References
- Read `ARCHITECTURE.md` before adding a new top-level module
- Release process: `docs/releasing.md`
```

## Prefer Enforcement Over Prose

A rule the agent must remember is weaker than a check that fails. When a rule matters, encode it as a lint, type, test, or CI check, and give the error message a fix hint. Then delete the prose rule or keep one line pointing at the check.

## Writing and Maintaining It

- **Write it by hand, or cut hard.** Do not ship an auto-generated file (`/init` output) as-is; the
  study found generated files add cost without gains. Draft with an agent if useful, then delete
  every inferable line.
- **Add rules reactively.** When an agent makes the same mistake twice, add the one line that would
  have prevented it, or better, a check.
- **Stale rules are worse than none.** Agents follow them faithfully. Remove a rule in the same
  change that makes it untrue.
- **Bullets and code blocks, not prose.**
- **Other tools:** if a tool reads a different file (for example `CLAUDE.md`), symlink it to
  `AGENTS.md` instead of keeping two copies.

## Monorepos

Root AGENTS.md for repo-wide rules; a nested AGENTS.md per package for what is different there.
The nearest file to the edited code applies along with the root. Do not repeat root rules in nested
files.

## Checklist

- [ ] Every line passes "would a capable agent get this wrong without it?"
- [ ] No directory tour or codebase overview
- [ ] Non-obvious commands, especially single-test and codegen, are listed
- [ ] Nothing restates what lint, format, or type checks enforce
- [ ] Guardrails are explicit (never do / ask first)
- [ ] Rules that can be checks are checks
- [ ] Every rule is true today
- [ ] Short enough that you would read all of it (usually well under 100 lines)
