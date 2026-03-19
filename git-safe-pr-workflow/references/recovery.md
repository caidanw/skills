# Recovery Playbook

Use this guide when the branch already looks wrong, a rebase went badly, or the user needs to undo a mistake safely.

## First Rule

Preserve information before deleting anything. Prefer recovery and reversal over destructive cleanup.

## Recover From A Bad Rebase

Use this path when a user says:

- "my branch looks wrong after rebase"
- "old commits came back"
- "I lost my changes"

Workflow:

1. Inspect `git status` to see whether rebase is still in progress.
2. If rebase is active and the goal is to stop, abort it.
3. If history was already rewritten, inspect `git reflog` to find the pre-rebase state.
4. Return to the last known-good commit only after naming it explicitly.
5. Re-sync with `origin/main` using a merge instead of repeating the rebase.

Explain `reflog` simply: it is the local history of where branch pointers and `HEAD` used to point.

## Undo Pushed Work Safely

Use `git revert` when:

- the commit is already pushed
- the branch is shared or has an open PR
- you want a clear, collaboration-safe undo

Do not default to reset or history rewrite for pushed work.

## Undo Local Unpublished Work

If the work is local-only, choose the least destructive option that matches the user's goal:

- discard unstaged edits in one file
- unstage changes but keep file edits
- drop an unpublished local commit

Do not jump directly to `reset --hard` unless the user explicitly wants to throw away all local work.

## Wrong-Branch Commit

If work was committed on the wrong branch:

1. preserve the commit
2. move or copy it to the correct branch
3. clean up the wrong branch with the safest method for whether it is pushed or local-only

The point is to relocate work, not delete it.

## Accidental Merge Or Pull

If a user accidentally merged or pulled and wants out:

1. determine whether the result was committed
2. determine whether it was pushed
3. if local-only, use the safest local undo path
4. if pushed, use `revert`

## Recovery Checklist

- [ ] is the branch shared or pushed?
- [ ] is there an in-progress merge or rebase?
- [ ] what is the last known-good commit?
- [ ] can this be fixed with `revert` instead of rewrite?
- [ ] have you explained the recovery point to the user?
