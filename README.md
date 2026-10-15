# Skills

A collection of [Agent Skills](https://skills.sh/) for AI coding agents.

## What are Skills?

Skills are reusable capabilities for AI agents. They provide procedural knowledge that helps agents accomplish specific tasks more effectively. Each skill is a folder containing a `SKILL.md` file with instructions, examples, and guidelines.

## Installation

Install any skill from this repo using the [skills CLI](https://skills.sh/):

```bash
npx skills add caidanw/skills
```

To install a specific skill:

```bash
npx skills add caidanw/skills@<skill-name>
```

## Available Skills

<!-- skills-start -->
| Skill | Description |
| --- | --- |
| [`agents-md`](./skills/agents-md/) | Write effective AGENTS.md files that give coding agents only the context they cannot infer from the repository. |
| [`architect`](./skills/architect/) | Sketch types, signatures, and module structure before code, then stay in the loop while implementation fills in. |
| [`architecture-md`](./skills/architecture-md/) | Generate an ARCHITECTURE.md file for a codebase following matklad's principles. |
| [`behavioral-testing`](./skills/behavioral-testing/) | Behavioral testing methodology — test what users experience, not how code is structured. |
| [`benchmark-checklist`](./skills/benchmark-checklist/) | Vet a perf measurement (limiter, tuning, limits, errors, repeatability, relevance, and whether the work happened) before you report or act on it. |
| [`blast-radius`](./skills/blast-radius/) | Find what a change could break somewhere else before it ships, beyond the diff, and prove the one fact it's safe because of by running real code instead of writing it up. |
| [`clear-communication`](./skills/clear-communication/) | Use clear, natural, reader-centered language for all agent communication. |
| [`code-comments`](./skills/code-comments/) | Write high-signal code comments for humans and coding agents. |
| [`correct`](./skills/correct/) | Find the mistakes agents keep repeating in this repo and make each one impossible. |
| [`create-verification-skill`](./skills/create-verification-skill/) | Generate a project-local verification skill that drives your app the way a user does — any language, framework, or platform. |
| [`design-system`](./skills/design-system/) | Build design system components and UI that are accessible, themeable, and visually consistent. |
| [`distill-to-skill`](./skills/distill-to-skill/) | Distill knowledge from any source — blog posts, articles, documentation, GitHub repos, video transcripts, books, papers — into a well-structured agent skill. |
| [`in-your-own-words`](./skills/in-your-own-words/) | Restate in your own words what you think the user's goals are and what problem they're trying to solve. |
| [`lean-ts-patterns`](./skills/lean-ts-patterns/) | Build lightweight TypeScript tools and libraries with few or no dependencies. |
| [`macos-swift-desktop`](./skills/macos-swift-desktop/) | Build native macOS desktop applications in Swift using AppKit and SwiftUI. |
| [`maintain-verification-skill`](./skills/maintain-verification-skill/) | Periodic pass that keeps a project's verification skill and feature map honest: parallel source readers per feature, one live session driving every feature, at most one PR of proven corrections. |
| [`modern-css`](./skills/modern-css/) | Write modern CSS using native features instead of legacy hacks, workarounds, and JavaScript. |
| [`no-use-effect`](./skills/no-use-effect/) | Prevent unnecessary React `useEffect` usage by steering code toward derived state, event handlers and form Actions, `key`-based resets, `useSyncExternalStore`, `useEffectEvent`, and framework or query-library data APIs. |
| [`sharpen`](./skills/sharpen/) | Sharpen a task before starting: the expert approach, what the user is really after, and the right level of specification. |
| [`show-me-your-work`](./skills/show-me-your-work/) | Keep a reviewable decision trail for long-running or unattended work: a TSV log with one row per decision (what, why, evidence, result). |
| [`simplify`](./skills/simplify/) | Simplify and refine recently modified code for clarity and consistency. |
| [`technical-writing`](./skills/technical-writing/) | Write and review technical docs, RFCs, design docs, readmes, PR descriptions, commit messages, issues, and PRDs. |
| [`type-system-discipline`](./skills/type-system-discipline/) | Make the compiler reject impossible states, mixed-up primitives, and unhandled variants, and parse external data once at system boundaries. |
| [`typescript-best-practices`](./skills/typescript-best-practices/) | TypeScript best practices: simple, composable, soundly typed code, with rules for unions, branded types, parsing, narrowing, casts, exhaustiveness, errors, and the TS 6/7 compiler baseline. |
| [`typescript-refactoring`](./skills/typescript-refactoring/) | Systematically refactor TypeScript codebases for readability and type safety. |
| [`unslop`](./skills/unslop/) | Cut AI tells from any writing. |
<!-- skills-end -->

## Creating a Skill

Each skill follows a simple structure:

```
skills/skill-name/
└── SKILL.md
```

The `SKILL.md` file contains YAML frontmatter and markdown instructions:

```markdown
---
name: skill-name
description: A clear description of what this skill does and when to use it
---

# Skill Name

[Instructions for the agent go here]
```

After adding, removing, or renaming a skill, regenerate the table above:

```bash
bash scripts/update-readme.sh
```

Retired skills live in [`archive/`](./archive/) and are not installable.

## License

MIT
