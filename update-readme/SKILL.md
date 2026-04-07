---
name: update-readme
description: Use when adding, removing, or renaming a skill in this repository to keep the Available Skills table in README.md current.
---

# Update README

After any change to a skill's `name`, `description`, or directory, regenerate the Available Skills table:

```bash
node scripts/update-readme.js
```

The script scans every top-level `*/SKILL.md`, extracts the `name` and `description` from the YAML frontmatter, and replaces the `<!-- skills-start -->` / `<!-- skills-end -->` block in `README.md`.

## When to run

- After adding a new skill directory
- After editing the `name` or `description` field in any `SKILL.md`
- After renaming or deleting a skill directory

## How it works

1. Reads all top-level `*/SKILL.md` files
2. Parses YAML frontmatter (handles quoted values and `>` / `>-` block scalars)
3. Extracts the first sentence of each description
4. Sorts skills alphabetically by name
5. Replaces the marked region in `README.md` between `<!-- skills-start -->` and `<!-- skills-end -->`
