# Cleanup Worktree

Removes a git worktree and its associated local branch after a PR has been merged. Designed as the cleanup counterpart to `/implement`, which creates worktrees for isolated development.

## Prerequisites

- **Git 2.17+** — worktree features used by this skill require Git 2.17 or later

  ```powershell
  # Windows (PowerShell)
  git --version
  ```

  ```sh
  # Linux / macOS
  git --version
  ```

## Installation

Install the skill with the sync scripts.

- **Claude project-level** (one project): `<project-root>\.claude\skills\`
- **Claude user-level** (all projects): `~\.claude\skills\`
- **Copilot project-level** (one project): `<project-root>\.github\skills\`
- **Copilot user-level** (all projects): `~\.copilot\skills\`

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-sync-skills.ps1
.\bin\seiji-copilot-sync-skills.ps1
```

```sh
# Linux / macOS
./bin/seiji-claude-sync-skills
# POSIX Copilot sync is planned.
```

## Permissions

This skill uses only local git commands. For Claude Code, add the following permission to your settings if not already present:

```json
"Bash(git worktree *)"
```

The remaining git operations (`git branch`, `git rev-parse`, `git status`, `git symbolic-ref`, `git log`) are covered by [`settings\base.json`](../../settings/base.json).

For Copilot CLI, approve the requested git shell commands interactively or launch Copilot with equivalent `--allow-tool` permissions for the git subcommands used by the skill.

## Usage

```
/cleanup-worktree                                           # Auto-detect or list and choose
/cleanup-worktree u/seijimorimoto/add-caching-layer         # Target a specific branch
/cleanup-worktree ../worktrees/add-caching-layer            # Target a specific worktree path
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| branch-or-path | No | Auto-detected | Branch name or worktree path to clean up |

## Behavior by Context

| Context | What happens |
|---------|-------------|
| Inside a secondary worktree, no args | Auto-targets the current worktree |
| Inside main worktree, one secondary exists | Auto-targets the only secondary worktree |
| Inside main worktree, multiple secondaries exist | Lists worktrees and asks user to choose |
| Inside main worktree, no secondaries exist | Prints "Nothing to clean up" and stops |
| Argument provided, matches a worktree | Targets that worktree directly |
| Argument provided, no match | Stops with an error message |

## Safety Checks

The skill performs these checks before any destructive action:

1. **Uncommitted changes** — warns and asks for confirmation if the worktree has unsaved work
2. **Merge status** — warns and asks for confirmation if the branch appears unmerged (note: squash-merged branches always appear unmerged to git)
3. **Branch in use** — refuses to delete a branch still checked out in another worktree

## Workflow

```
1. Preflight    ->  Verify git repo + list worktrees + detect main branch
2. Identify     ->  Auto-detect or resolve target from arguments
3. Safety       ->  Check uncommitted changes + merge status
4. Exit         ->  Switch to main worktree if needed
5. Remove       ->  git worktree remove (with fallback to --force or prune)
6. Delete       ->  git branch -D (local only, not remote)
7. Summary      ->  Confirm what was cleaned up
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No worktree found for '...'" | Verify the branch or path is correct: `git worktree list` |
| Worktree removal fails | The worktree may have uncommitted changes. Confirm when prompted, or manually clean up with `git worktree remove --force <path>` |
| Branch deletion fails | The branch may be checked out in another worktree. Check with `git worktree list` |
| Stale worktree (path deleted manually) | The skill auto-prunes stale entries via `git worktree prune` |
| "Cannot delete branch checked out in another worktree" | Switch that other worktree to a different branch first, or remove it first |
