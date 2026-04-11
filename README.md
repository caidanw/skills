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
| [`agent-first-repo`](./agent-first-repo/) | Structure a repository and its documentation so AI coding agents can work effectively. |
| [`agents-md`](./agents-md/) | Write effective AGENTS. |
| [`architecture-md`](./architecture-md/) | Generate an ARCHITECTURE. |
| [`behavioral-testing`](./behavioral-testing/) | Behavioral testing methodology — test what users experience, not how code is structured. |
| [`code-comments`](./code-comments/) | Write high-signal code comments for humans and coding agents. |
| [`design-system`](./design-system/) | Build design system components and UI that are accessible, themeable, and visually polished. |
| [`distill-to-skill`](./distill-to-skill/) | Distill knowledge from any source — blog posts, articles, documentation, GitHub repos, video transcripts, books, papers — into a well-structured agent skill. |
| [`Git Worktree`](./worktree/) | Create, remove, and list git worktrees in a standardized location |
| [`git-safe-pr-workflow`](./git-safe-pr-workflow/) | Safe GitHub pull request workflow for low-experience Git users. |
| [`karpathy-guidelines`](./karpathy-guidelines/) | Behavioral guidelines to reduce common LLM coding mistakes. |
| [`lean-ts-patterns`](./lean-ts-patterns/) | Patterns for building lightweight, zero-dependency TypeScript tools and libraries. |
| [`macos-swift-desktop`](./macos-swift-desktop/) | Build native macOS desktop applications in Swift using AppKit and SwiftUI. |
| [`modern-css`](./modern-css/) | Teaches agents to write modern CSS using native features instead of legacy hacks, workarounds, and JavaScript. |
| [`no-use-effect`](./no-use-effect/) | Prevent unnecessary React `useEffect` usage by steering code toward derived state, event handlers, memoization, `key`-based resets, `useSyncExternalStore`, and framework or query-library data APIs. |
| [`parse-dont-validate`](./parse-dont-validate/) | Type-driven design principle: transform unstructured data into structured types at system boundaries, making illegal states unrepresentable. |
| [`Technical Writing`](./tech-writing/) | Write clean, terse technical docs — commits, issues, PRDs, specs, and technical communication |
| [`TypeScript`](./typescript/) | Write clean, pragmatically functional TypeScript — simple, composable, soundly typed |
| [`typescript-refactoring`](./typescript-refactoring/) | Systematically refactor TypeScript codebases for readability, type safety, and AI-friendliness. |
| [`update-readme`](./update-readme/) | Use when adding, removing, or renaming a skill in this repository to keep the Available Skills table in README. |
<!-- skills-end -->

## Creating a Skill

Each skill follows a simple structure:

```
skill-name/
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

## License

MIT
