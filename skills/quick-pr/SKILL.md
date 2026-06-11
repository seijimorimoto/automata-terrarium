---
name: quick-pr
description: Create a branch, commit, push, open a GitHub PR, optionally squash-merge, and clean up
argument-hint: "[--title \"Title\"] [--branch name] [--base main|--target main] [--draft] [--no-merge]"
---

# GitHub Quick PR

Automates the full PR lifecycle for routine changes: create branch, stage, commit, push, create PR, squash-merge, and clean up.

## Usage

```
/quick-pr [--title "Title"] [--branch name] [--base main|--target main] [--draft] [--no-merge]
```

## Parameters

- `--title`: Custom PR title (auto-generated from commits if not provided)
- `--branch`: Custom branch name (auto-generated from changes if not provided)
- `--base` / `--target`: Target branch (default: repo's default branch, detected via `gh repo view`)
- `--draft`: Create the PR as a draft and skip merge
- `--no-merge`: Create the PR but do not merge it (useful when review is needed)

## Instructions

When this skill is invoked:

### Step 1 — Preflight Checks

Run these commands in parallel:

- `gh auth status` — Verify GitHub CLI is authenticated. If not, tell the user to run `gh auth login` and **stop**.
- `git status` — Check current branch, staged changes, unstaged changes, untracked files.
- `git log --oneline -5` — Recent commits for context.
- `git remote -v` — Confirm a GitHub remote exists. If no GitHub remote is found, **stop**.

### Step 2 — Parse Arguments

Parse `$ARGUMENTS` for:
- `--title "<value>"` — Custom PR title.
- `--branch <value>` — Custom branch name.
- `--base <value>` or `--target <value>` — Target branch. If not provided, detect the repo's default branch: `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`.
- `--draft` — Create the PR as a draft and skip merge.
- `--no-merge` — Flag to skip the merge step.

### Step 3 — Assess State

Determine the current state and decide which steps to execute:

| Current state | Actions needed |
|---|---|
| On base branch + no changes, no unpushed commits | Print "Nothing to do" and **stop** |
| On base branch + uncommitted changes | Branch → Commit → Push → PR → Merge |
| On feature branch + uncommitted changes | Commit → Push → PR → Merge |
| On feature branch + unpushed commits only | Push → PR → Merge |
| On feature branch + everything pushed | PR → Merge |

### Step 4 — Create Branch

**Skip if already on a feature branch** (i.e., not on the base branch).

1. Extract the GitHub username from the remote URL:
   ```bash
   git remote get-url origin | sed -E 's#.*(github\.com[:/])([^/]+)/.*#\2#'
   ```

2. Determine the branch name:
   - If `--branch` was provided: use it as-is if it already starts with `u/`, otherwise prepend `u/<username>/`.
   - If `--branch` was NOT provided: analyze the uncommitted changes (or staged diff) and generate a descriptive slug that summarizes the feature. Format: `u/<username>/<feature-slug>` (e.g., `u/seijimorimoto/add-weekly-status-w15`, `u/seijimorimoto/fix-typo-in-readme`).

3. Create the branch:
   ```bash
   git checkout -b '<branch-name>'
   ```

### Step 5 — Stage and Commit

**Skip if there are no uncommitted changes.**

1. Stage changes — prefer adding specific files by name rather than `git add -A`. Do NOT stage files that look like secrets (`.env`, credentials, tokens).
2. Analyze the diff and generate a commit message following Conventional Commits format:
   ```
   <type>(<scope>): <short summary in imperative mood>
   ```
3. Commit using single quotes around the message:
   ```bash
   git commit -m '<generated message>'
   ```

### Step 6 — Push

Push the branch to the remote:
```bash
git push -u origin '<branch-name>'
```

### Step 7 — Create PR

1. Check if a PR already exists for this branch:
   ```bash
   gh pr list --head '<branch-name>' --json number,url
   ```
   If a PR already exists, reuse it and skip to Step 8.

2. Generate the PR title:
   - If `--title` was provided, use it exactly.
   - Otherwise, analyze `git log <base>..HEAD --oneline` and generate a concise title (under 70 characters).

3. Generate the PR body with this format:
   ```markdown
   ## Summary
   [1-3 bullet points explaining what this PR does]

   ## Changes
   [Bulleted list of notable changes]

   ```

4. Create the PR:
   ```bash
   gh pr create --base '<base>' --head '<branch-name>' --title '<title>' [--draft if requested] --body '$(cat <<'\''EOF'\''
   <generated body>
   EOF
   )'
   ```

5. Display the PR URL.

### Step 8 — Merge

**Skip if `--no-merge` or `--draft` was specified.** If skipping, print the PR URL and **stop**.

1. Merge with squash strategy and delete the remote branch:
   ```bash
   gh pr merge '<pr-number-or-url>' --squash --delete-branch
   ```

2. **If merge fails** (required checks, merge conflicts, branch protection): print the PR URL, explain the error, and **stop**. Do NOT proceed to cleanup steps.

### Step 9 — Return to Base Branch

```bash
git checkout '<base>' && git pull
```

### Step 10 — Local Cleanup

Delete the local feature branch (force-delete because squash merge rewrites history):
```bash
git branch -D '<branch-name>'
```

### Step 11 — Summary

Print a brief summary:
- What was done (branch created, PR merged, etc.)
- The PR URL
- The resulting merge commit: `git log --oneline -1`

## Important Notes

- Always use **single quotes** around shell string arguments.
- If any step fails, **stop immediately** and report the error. Do not continue to subsequent steps.
- The squash merge strategy means all branch commits become a single commit on the base branch.
- Do NOT stage or commit files that look like secrets (`.env`, credentials, tokens).
- When generating branch names and commit messages, derive them from the actual changes — do not use generic timestamps or placeholder names.

## Examples

Simplest usage — stage everything, auto-name branch, auto-merge:
```
/quick-pr
```

With a custom title:
```
/quick-pr --title "Add weekly status report for W15"
```

With a custom branch name:
```
/quick-pr --branch add-weekly-status-w15
```

Create PR but skip merge (for changes that need review):
```
/quick-pr --no-merge
```

Target a different base branch:
```
/quick-pr --base develop
```
