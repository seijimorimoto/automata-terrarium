---
name: cleanup-worktree
description: Remove a git worktree and its associated local branch after PR merge
---

# Cleanup Worktree

Removes a local git worktree and deletes its associated local branch. Use this after a PR has been merged and the worktree is no longer needed.

## Usage

```copilot
Use the /cleanup-worktree skill
Use the /cleanup-worktree skill for u/seijimorimoto/add-caching-layer
Use the /cleanup-worktree skill for ..\worktrees\add-caching-layer
```

## Instructions

When this skill is invoked:

1. Run local git preflight checks:
   - `git rev-parse --is-inside-work-tree`
   - `git worktree list`
   - `git rev-parse --git-common-dir`
   - `git symbolic-ref --short HEAD`
   - `git rev-parse --show-toplevel`
2. Determine the main branch by checking `main`, `master`, then `develop`.
3. Resolve the target worktree from the user's argument, or auto-detect it from the current directory.
4. Before removing anything, check the target worktree for uncommitted changes with `git -C '<worktree-path>' status --porcelain`.
5. Check whether the target branch is merged into the main branch. If not, warn that squash-merged branches can look unmerged and ask before deleting.
6. If the current directory is inside the target worktree, switch to the main worktree path first.
7. Remove the worktree with `git worktree remove '<worktree-path>'`. Use `--force` only if the user already confirmed uncommitted changes can be discarded.
8. If the worktree is stale, run `git worktree prune` and verify it disappeared from `git worktree list`.
9. Delete the local branch with `git branch -D '<target-branch>'` only after confirming it is not checked out in any remaining worktree.
10. Print a short summary with the removed worktree, deleted branch, current location, and remaining worktree count.

## Safety rules

- Do not run network commands.
- Do not delete the remote branch.
- Do not use broad filesystem deletion unless `git worktree remove` unregisters the worktree but leaves the directory behind and the user has confirmed.
- Stop and report the error if any unexpected command fails.
