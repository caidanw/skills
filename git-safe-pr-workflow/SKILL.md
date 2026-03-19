---
name: git-safe-pr-workflow
description: >-
  Safe GitHub pull request workflow for low-experience Git users. Use when pulling,
  syncing a feature branch with `main`, resolving conflicts, undoing mistakes,
  recovering from a bad rebase, or deciding how to merge a PR while keeping `main`
  clean. Triggers on: "update my branch", "rebase my branch", "resolve git conflicts",
  "recover from rebase", "undo pushed commit", "keep main clean", "squash merge".
---

# Git Safe Pr Workflow

## Overview

Guide users through a GitHub-first PR workflow that keeps `main` clean without requiring
frequent local rebases. Prefer short-lived feature branches, merge `origin/main` into the
feature branch when syncing, and land changes with `Squash and merge`.

Bias toward safety over elegance. Choose reversible operations, avoid rewriting shared
history, and teach the user in small steps while you work.

## Safe Defaults

- Treat `main` and `master` as shared, sensitive branches.
- Use a short-lived feature branch for every task.
- Assume a pushed branch or open PR may already be shared.
- Prefer `git fetch` before any sync, merge, or recovery action.
- Prefer merging `origin/main` into a feature branch over rebasing it.
- Prefer `git revert` over rewriting history when commits may already be pushed.
- Prefer `Squash and merge` to keep `main` clean.

## Inspect First

Before any Git operation that changes history, branches, or remote state, inspect:

- current branch and whether it is the default branch
- clean vs dirty working tree
- upstream tracking branch and whether local commits are pushed
- whether the branch has an open PR or appears shared
- staged and unstaged diff when undoing or syncing work

If you cannot determine whether a branch is shared, assume it is shared and choose the
safer path.

## Standard Workflow

Use this as the default GitHub workflow for low-experience users:

1. Branch from `main`.
2. Commit locally on the feature branch in small logical steps.
3. Open a PR early.
4. When the branch falls behind `main`, merge `origin/main` into the feature branch.
5. Resolve conflicts carefully and verify the final code, not just the merge markers.
6. Push the updated branch.
7. Merge with `Squash and merge`.
8. Delete the feature branch after merge.

Do not teach users to routinely rebase pushed PR branches just to get the latest `main`.
That workflow is where many novices re-introduce old code or lose work.

## Opening PRs

When helping a user open a PR, treat the PR title as the likely final squash-merge commit.

- Write the title so it reads well on `main` after `Squash and merge`.
- Use a concise Conventional Commit style title when the repo uses that convention.
- Describe the final outcome, not the implementation journey or review process.
- Avoid titles like `WIP`, `fix stuff`, `address comments`, or `update branch`.

Good default patterns:

- `feat: add <skill-name> skill`
- `feat(<skill-name>): add <capability>`
- `fix(<skill-name>): correct <problem>`
- `docs: document <policy or workflow>`

For the PR body:

- briefly state what changed
- briefly state why it changed
- mention testing or validation if relevant

If the repo uses GitHub squash merges, prefer the PR title as the default squash commit message.

## Sync Decision Tree

- **Need the latest `main` on a feature branch?** Use `fetch`, then merge `origin/main` into the
  feature branch.
- **Need a clean `main` history?** Rely on `Squash and merge`, not local rebasing of the feature
  branch.
- **Need to clean up unpublished local commits?** Rebase is acceptable only if the branch is
  clearly private, unpublished, and not under review.
- **Need to undo pushed work?** Use `revert`.
- **Need to discard local-only work?** Use the least destructive local undo that matches the goal.

If a user asks to rebase a pushed branch, explain why that is risky and propose merging
`origin/main` instead.

## Conflict Resolution Rules

- Resolve conflicts to the desired final code state, not by blindly taking both sides.
- Assume old bugs can be reintroduced during conflict resolution.
- After resolving conflicts, inspect the affected files and summarize what changed.
- Run targeted verification after conflicts: tests, build, or focused checks in the touched area.
- If the resolution is non-obvious, explain it briefly to the user while making the change.

For detailed conflict-handling steps and examples, read `references/conflict-resolution.md`.

## Recovery Rules

- If a merge is in progress and the user wants to stop, abort the merge rather than improvising.
- If a rebase is in progress and has gone wrong, stop and recover with `reflog` or rebase abort.
- If the wrong commit was pushed, prefer `revert`.
- If work was committed to the wrong branch, preserve it and move it rather than deleting it.
- When recovering history, explain what reference point you are returning to and why.

For recovery playbooks, read `references/recovery.md`.

## Refuse or Warn Hard

- Do not commit directly to `main` unless the user explicitly asks and the repo policy allows it.
- Do not force-push `main` or other protected branches.
- Do not rebase a pushed/shared branch by default.
- Do not use `git reset --hard`, `git clean -fd`, branch deletion, or tag deletion unless the user
  clearly wants destructive cleanup.
- Do not bypass branch protections, required checks, or required review flows.

If the user explicitly wants a risky operation, explain the safer alternative first. Only proceed
when the request is clear and the branch is not a protected/shared branch.

## Teaching Behavior

Teach in short, repeatable notes while working:

- State what you are about to do and why it is the safer path.
- When rejecting rebase, explain that rebase rewrites commit history and is easy to misuse once
  a branch is pushed.
- When merging `origin/main`, explain that this preserves the branch's existing commits and is
  easier to recover from.
- After recovery, explain what went wrong, how you recovered, and what safer habit to use next time.
- Avoid long Git lectures. Teach the next decision, not the whole tool.

## GitHub Settings To Recommend

When asked how to support this workflow at the repo level, recommend:

- protect `main`
- require pull requests before merge
- require status checks
- require at least one review
- enable `Squash and merge`
- disable `Rebase and merge`
- optionally disable regular merge commits if the team wants squash-only history
- set the default squash commit message to `Pull request title`
- auto-delete head branches after merge

For repo policy details, read `references/repo-settings.md`.

## Quick Checklist

Before syncing a feature branch:

- [ ] confirm you are on the feature branch, not `main`
- [ ] fetch remote changes
- [ ] check for uncommitted work
- [ ] merge `origin/main`, do not rebase by default
- [ ] inspect and verify conflict resolutions

Before pushing:

- [ ] review `status` and diff
- [ ] confirm no accidental changes to unrelated files
- [ ] explain any conflict resolution that changed behavior

Before undoing:

- [ ] determine whether the commits are pushed
- [ ] choose `revert` for pushed work
- [ ] use local-only undo only for unpublished work
