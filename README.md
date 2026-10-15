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
| [`architecture-md`](./skills/architecture-md/) | Generate an ARCHITECTURE.md file for a codebase following matklad's principles. |
| [`behavioral-testing`](./skills/behavioral-testing/) | Behavioral testing methodology — test what users experience, not how code is structured. |
| [`clear-communication`](./skills/clear-communication/) | Use clear, natural, reader-centered language for all agent communication. |
| [`code-comments`](./skills/code-comments/) | Write high-signal code comments for humans and coding agents. |
| [`design-system`](./skills/design-system/) | Build design system components and UI that are accessible, themeable, and visually polished. |
| [`distill-to-skill`](./skills/distill-to-skill/) | Distill knowledge from any source — blog posts, articles, documentation, GitHub repos, video transcripts, books, papers — into a well-structured agent skill. |
| [`lean-ts-patterns`](./skills/lean-ts-patterns/) | Build lightweight TypeScript tools and libraries with few or no dependencies. |
| [`macos-swift-desktop`](./skills/macos-swift-desktop/) | Build native macOS desktop applications in Swift using AppKit and SwiftUI. |
| [`modern-css`](./skills/modern-css/) | Write modern CSS using native features instead of legacy hacks, workarounds, and JavaScript. |
| [`no-use-effect`](./skills/no-use-effect/) | Prevent unnecessary React `useEffect` usage by steering code toward derived state, event handlers and form Actions, `key`-based resets, `useSyncExternalStore`, `useEffectEvent`, and framework or query-library data APIs. |
| [`simplify`](./skills/simplify/) | Simplify and refine recently modified code for clarity and consistency. |
| [`technical-writing`](./skills/technical-writing/) | Write clean, terse technical docs — commits, issues, PRDs, specs, and technical communication |
| [`type-system-discipline`](./skills/type-system-discipline/) | Make the compiler reject impossible states, mixed-up primitives, and unhandled variants, and parse external data once at system boundaries. |
| [`typescript-best-practices`](./skills/typescript-best-practices/) | TypeScript best practices: simple, composable, soundly typed code, with rules for unions, branded types, parsing, narrowing, casts, exhaustiveness, errors, and the TS 6/7 compiler baseline. |
| [`typescript-refactoring`](./skills/typescript-refactoring/) | Systematically refactor TypeScript codebases for readability and type safety. |
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
