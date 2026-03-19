# GitHub Repo Settings

Use this guide when the user wants repo-level enforcement to support the safer workflow.

## Recommended Defaults

- protect `main`
- require pull requests before merge
- require at least one review
- require status checks
- require conversation resolution if the team uses review comments heavily
- enable auto-delete head branches

## Merge Methods

For this workflow, recommend:

- enable `Squash and merge`
- disable `Rebase and merge`

Optional:

- disable regular merge commits if the team wants every PR to become one clean commit on `main`

## Why Squash Merge Fits This Skill

- feature branches can have messy work-in-progress commits without polluting `main`
- `main` stays readable for beginners
- users do not need to learn local history cleanup just to contribute safely

## What These Settings Do Not Solve

- bad conflict resolution while syncing a feature branch
- accidental local rebases before the PR is merged
- poor branch hygiene on long-lived feature branches

That is why this skill still guides local merge-based sync and recovery.
