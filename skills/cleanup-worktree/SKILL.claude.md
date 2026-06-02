---
name: cleanup-worktree
description: Remove a git worktree and its associated local branch after PR merge
argument-hint: "[branch-or-path]"
---

# Cleanup Worktree

Removes a git worktree and deletes its associated local branch. Intended for post-merge cleanup after `/implement` creates a worktree for isolated development.

## Usage

```
/cleanup-worktree
/cleanup-worktree my-feature-branch
/cleanup-worktree ../worktrees/my-feature
```

## Parameters

- `$ARGUMENTS` (optional): A branch name or worktree path to target. If omitted, the skill auto-detects the current worktree or lists all worktrees for selection.

## Instructions

When this skill is invoked:

### Step 1 — Preflight Checks

Run these commands in parallel:

- `git rev-parse --is-inside-work-tree` — Verify we are inside a git repository. If not, **stop** and tell the user to run this from inside a git repo.
- `git worktree list` — List all worktrees for later use.
- `git rev-parse --git-common-dir` — Determine the common git directory (used to distinguish the main worktree from secondary worktrees).
- `git symbolic-ref --short HEAD` — Get the current branch name.
- `git rev-parse --show-toplevel` — Get the current worktree root path.

Determine the **main branch** name by checking which of these branches exists (in order): `main`, `master`, `develop`. Use:
```bash
git branch --list 'main' 'master' 'develop' --format='%(refname:short)'
```
Pick the first result. If none exist, **stop** and ask the user to specify the main branch.

### Step 2 — Identify Target Worktree

Parse `$ARGUMENTS`:

1. **If `$ARGUMENTS` is provided:**
   - Check if it matches a branch name from `git worktree list` output. If so, select that worktree.
   - Otherwise, check if it matches a worktree path (absolute or relative) from `git worktree list` output. If so, select that worktree.
   - If no match is found, **stop** and tell the user: "No worktree found for '<argument>'. Run `git worktree list` to see available worktrees."

2. **If `$ARGUMENTS` is NOT provided:**
   - Determine if the current directory is inside a **secondary worktree** (not the main worktree). A secondary worktree's `git rev-parse --git-common-dir` points to the main worktree's `.git` directory (e.g., a path containing `.git/worktrees/`) rather than being `.git` itself.
   - **If inside a secondary worktree:** Auto-select the current worktree as the target.
   - **If inside the main worktree (or bare repo):** List all secondary worktrees from Step 1. If there is exactly **one** secondary worktree, auto-select it. If there are **multiple** secondary worktrees, display them as a numbered list with branch name, path, and HEAD commit, then ask the user which one to clean up. If there are **zero** secondary worktrees, print "No secondary worktrees found. Nothing to clean up." and **stop**.

After this step, you must have identified:
- **Target worktree path** (absolute path)
- **Target branch name** (the branch checked out in that worktree)

### Step 3 — Safety Checks

Perform the following checks on the target worktree:

1. **Check for uncommitted changes** in the target worktree:
   ```bash
   git -C '<worktree-path>' status --porcelain
   ```
   If the output is non-empty, **warn** the user: "The worktree at '<path>' has uncommitted changes that will be lost." List the changed files. Ask the user for confirmation before proceeding. If the user declines, **stop**.

2. **Check if the branch has been merged** into the main branch:
   ```bash
   git branch --merged '<main-branch>' --list '<target-branch>'
   ```
   - If the target branch appears in the output, it is merged. Proceed.
   - If it does NOT appear, check for unmerged commits:
     ```bash
     git log '<main-branch>'..'<target-branch>' --oneline --max-count=10
     ```
     If this shows commits, the branch has unmerged commits (or was squash-merged — git cannot distinguish these). **Warn** the user: "Branch '<target-branch>' appears to have unmerged commits (N commits ahead of '<main-branch>'). This is expected if the PR was squash-merged. Are you sure you want to delete it?" Ask for confirmation. If the user declines, **stop**.

3. **Note if the user is currently inside the target worktree.** This will be needed in Step 4.

### Step 4 — Exit Target Worktree (if needed)

If the current working directory is inside the target worktree:

1. Identify the main worktree path (the first entry from `git worktree list` is always the main worktree).
2. Tell the user: "You are currently inside the worktree being removed. Switching to the main worktree at '<main-worktree-path>'."
3. Change to the main worktree directory:
   ```bash
   cd '<main-worktree-path>'
   ```

### Step 5 — Remove Worktree

1. First, try a clean removal:
   ```bash
   git worktree remove '<worktree-path>'
   ```

2. If the above fails due to uncommitted changes (and the user already confirmed in Step 3), force the removal:
   ```bash
   git worktree remove --force '<worktree-path>'
   ```

3. If the removal fails because the directory no longer exists on disk (stale worktree), prune it:
   ```bash
   git worktree prune
   ```
   Then verify the worktree is no longer listed in `git worktree list`.

4. If removal fails for any other reason, **stop** and report the error.

5. **Verify the directory is gone.** After removal, check whether the worktree folder still exists on disk:
   ```bash
   test -d '<worktree-path>' && echo 'EXISTS' || echo 'GONE'
   ```
   If it still exists, delete it:
   ```bash
   rm -rf '<worktree-path>'
   ```
   This handles edge cases where `git worktree remove` unregisters the worktree but leaves the directory behind (e.g., due to lock files or permissions).

### Step 6 — Delete Local Branch

1. Verify the branch still exists locally:
   ```bash
   git branch --list '<target-branch>'
   ```
   If the branch does not exist (already deleted), skip this step.

2. Check that the branch is not checked out in any remaining worktree:
   ```bash
   git worktree list
   ```
   If the branch is still checked out in another worktree, **stop** and tell the user: "Branch '<target-branch>' is still checked out in worktree '<other-path>'. Cannot delete it."

3. Delete the local branch:
   ```bash
   git branch -D '<target-branch>'
   ```
   Use `-D` (force delete) because squash-merged branches are not recognized as merged by git.

4. If branch deletion fails, report the error but do NOT undo the worktree removal.

### Step 7 — Summary

Print a brief summary:

- Worktree removed: `<worktree-path>`
- Branch deleted: `<target-branch>`
- Current location: `<main-worktree-path>` (if we switched)
- Remaining worktrees: run `git worktree list` and show the count (e.g., "1 worktree remaining (main only)" or "N worktrees remaining")

## Important Notes

- Always use **single quotes** around shell string arguments (per project CLAUDE.md).
- If any step fails unexpectedly, **stop immediately** and report the error. Do not continue to subsequent steps.
- This skill only deletes the **local** branch. It does NOT delete the remote branch — that is typically handled by the merge process (e.g., GitHub's "Delete branch" option on PR merge, or `--delete-branch` in `gh pr merge`).
- When checking if a branch is merged, squash merges will NOT appear in `git branch --merged`. The fallback check using `git log <main>..<target>` is essential — it shows commits but the user can confirm the PR was already merged.
- Do NOT run `git fetch` or any network operations. This skill is entirely local.
- If the user is inside the worktree being deleted, switch to the main worktree before removing it.

## Examples

Run from inside the worktree to clean up (auto-detects):
```
/cleanup-worktree
```

Specify a branch name:
```
/cleanup-worktree u/seijimorimoto/add-caching-layer
```

Specify a worktree path:
```
/cleanup-worktree ../worktrees/add-caching-layer
```

Run from main worktree when multiple worktrees exist (will prompt for selection):
```
/cleanup-worktree
```
