# GitHub Quick PR

Automates the full PR lifecycle for routine, no-review-needed changes in GitHub repos with PR-only workflows. One command to: create a branch, stage, commit, push, open a PR, squash-merge, and clean up.

## Prerequisites

- **GitHub CLI (`gh`)** — [Install guide](https://cli.github.com/)

  ```powershell
  # Windows (PowerShell)
  winget install --id GitHub.cli
  ```

  ```sh
  # Linux / macOS
  brew install gh
  ```

- **Authenticated with GitHub** — Sign in with:

  ```powershell
  gh auth login
  ```

- **Git** — configured with user name and email

## Installation

Copy the skill folder to either location:

- **Project-level** (one project): `<project-root>\.claude\skills\`
- **User-level** (all projects): `~\.claude\skills\`

```powershell
# Windows (PowerShell)

# Project-level
Copy-Item -Recurse skills\quick-pr <your-project>\.claude\skills\

# User-level
Copy-Item -Recurse skills\quick-pr ~\.claude\skills\

# Or symlink (project-level)
New-Item -ItemType SymbolicLink -Path <your-project>\.claude\skills\quick-pr -Target (Resolve-Path skills\quick-pr)
```

```sh
# Linux / macOS

# Project-level
cp -r skills/quick-pr <your-project>/.claude/skills/

# User-level
cp -r skills/quick-pr ~/.claude/skills/

# Or symlink (project-level)
ln -s "$(pwd)/skills/quick-pr" <your-project>/.claude/skills/quick-pr
```

## Permissions

This skill uses the GitHub CLI (`gh`). Add the permissions from [`settings/github.json`](../../settings/github.json) to your Claude Code settings file to avoid permission prompts.

Git permissions (`git checkout`, `git push`, etc.) are covered by [`settings/base.json`](../../settings/base.json).

## Usage

```bash
/quick-pr                                          # Auto-everything: branch, commit, PR, merge
/quick-pr --title "Add weekly status for W15"      # Custom PR title
/quick-pr --branch add-weekly-status-w15           # Custom branch name
/quick-pr --no-merge                               # Create PR but skip merge
/quick-pr --base develop                           # Target a different base branch
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--title` | No | Auto-generated from commits | PR title |
| `--branch` | No | Auto-generated from changes | Feature branch name (prefixed with `u/<username>/`) |
| `--base` | No | Repo's default branch | Target branch for the PR |
| `--no-merge` | No | `false` | Create the PR but do not merge it |

## Behavior by State

The skill detects your current state and runs only the steps that are needed:

| Starting state | What happens |
|---|---|
| On base branch, no changes | Prints "Nothing to do" and stops |
| On base branch, uncommitted changes | Creates branch → commits → pushes → creates PR → merges → cleans up |
| On feature branch, uncommitted changes | Commits → pushes → creates PR → merges → cleans up |
| On feature branch, unpushed commits | Pushes → creates PR → merges → cleans up |
| On feature branch, everything pushed | Creates PR → merges → cleans up |
| PR already exists for branch | Reuses existing PR → merges → cleans up |

## Workflow

```
1. Preflight    →  Verify gh auth + GitHub remote
2. Branch       →  Create u/<username>/<feature-slug> (or use existing)
3. Commit       →  Stage changes + Conventional Commits message
4. Push         →  Push branch to origin
5. PR           →  Create GitHub PR (or reuse existing)
6. Merge        →  Squash merge + delete remote branch
7. Cleanup      →  Return to base branch + pull + delete local branch
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `gh: command not found` | Install GitHub CLI: `winget install --id GitHub.cli` (Windows) or `brew install gh` (macOS) |
| `gh auth` not logged in | Run `gh auth login` and follow the prompts |
| Merge blocked by checks | The skill leaves the PR open and prints its URL. Wait for checks to pass, then merge manually or re-run `/quick-pr` |
| Merge blocked by branch protection | Adjust branch protection rules in GitHub settings, or use `/quick-pr --no-merge` and merge via the GitHub UI |
| No GitHub remote found | Verify the repo has a GitHub remote: `git remote -v` |
| Pre-commit hook blocks commit | The skill creates a feature branch before committing, so the hook should not trigger. If it does, check your hook logic |

---