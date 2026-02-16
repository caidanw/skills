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

| Skill | Description |
| --- | --- |
| *Coming soon* | New skills will be added here |

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
