---
name: ship
description: "Commit the work logically, open the PR, and hand over the merge order as plain text. Use for /ship."
disable-model-invocation: true
---

# Ship

Get the finished work into a reviewable PR and tell the user how to land it.

1. Commit logically: each commit holds one change and only the files or hunks that belong to it, with a terse Conventional Commits message. Leave plan files, scratch files, and test data out.
2. Rebase onto a freshly fetched main. Rebase, never merge main in. Ask before rewriting a branch someone else has checked out. Regenerate generated files instead of hand-resolving their conflicts.
3. Push and open the PR ready for review. Use a draft only while the work is still changing, so nobody merges it by accident. Keep the body short: why, what changed, what is out of scope, and how it was verified. Link the ticket, and move it to In Review if the tracker does not do that automatically.
4. Check CI. Fix failures your change caused. For failures that are also on main, say so and leave them.
5. Hand over, as plain text ready to copy:
   - The PR links.
   - The merge order, when there is more than one PR.
   - Any migration steps before or after the merge, from the repo's `AGENTS.md`.
   - Anything that blocks merging.
6. Merge only when the user tells you to. Then squash-merge, confirm the change is on main, and delete the merged branch locally and on the remote.

**Done when:** the PR is open with CI checked, and the user has the links and merge order in one copyable block.
