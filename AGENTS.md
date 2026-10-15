# AGENTS.md

- Each directory under `skills/` with a `SKILL.md` is a published skill (`npx skills add caidanw/skills`).
- After adding, removing, or renaming a skill, or editing a `name`/`description`, run `bash scripts/update-readme.sh`. Never edit the table between `<!-- skills-start -->` and `<!-- skills-end -->` by hand.
- Retire a skill with `git mv skills/<name> archive/<name>`. Keep `archive/` at the repo root: `npx skills` scans `skills/` several levels deep but the root only one level, so `archive/` stays uninstallable.
