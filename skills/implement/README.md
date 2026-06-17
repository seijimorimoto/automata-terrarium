# Implement Plan

Implements a plan from a session, local file, issue, PR, work item, or another readable reference. The skill creates an isolated branch or worktree, applies the plan one step at a time with one logical commit per step, runs verification, opens a draft PR, and posts unresolved verify findings.

## Prerequisites

- **Git** — configured with user name and email.

  ```powershell
  git --version
  ```

  ```sh
  git --version
  ```

- **PR-creation skill** — `/quick-pr` for GitHub or `/ado-pr` for Azure DevOps.
- **Verification skills** — `/standards-check` and `/doc-review`; `/coverage-check` is used when a coverage tool is detectable. Runtime-native review/security/simplification checks or equivalent available skills are attempted best-effort unless skipped with `--skip-native-verify`.

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
# Linux / macOS / POSIX
./bin/seiji-claude-sync-skills
# POSIX Copilot sync is tracked by #21.
```

## Usage

```
# Implement the plan from the current session
/implement

# Read a local plan file
/implement --plan-source plans\dual-runtime-workflow-migration.md

# Read an issue or PR URL
/implement --plan-source https://github.com/owner/repo/issues/123

# Use a custom branch and target
/implement --branch u/alice/cool-feature --target develop

# Use a custom worktree parent directory
/implement --worktree-dir ..\feature-worktrees

# Work in the current tree instead of a new worktree
/implement --no-worktree

# Skip optional native/equivalent checks and coverage
/implement --skip-native-verify --skip-coverage
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--plan-source` | No | `session` | Session discussion, local file path, issue/PR URL, work item, or other readable reference |
| `--branch` | No | Generated from project instructions or plan title | Feature branch name |
| `--target` | No | Remote default branch, then `main` | Target branch for the PR |
| `--worktree-dir` | No | `<repo-root>\.worktrees\` | Parent directory for generated worktree folders; relative paths resolve from the original repo root |
| `--no-worktree` | No | `false` (worktrees on by default) | Work in the current tree instead of creating a git worktree |
| `--pr-tool` | No | GitHub -> `/quick-pr`, Azure DevOps -> `/ado-pr` | PR-creation skill |
| `--skip-native-verify` | No | `false` | Skip best-effort runtime-native or equivalent review, security, and simplification checks |
| `--skip-verify` | No | off | Skip all verification |
| `--skip-standards`, `--skip-coverage`, `--skip-doc-review` | No | none | Skip individual repo-provided checks |

## Workflow

```text
1. Read plan      -> session, file, issue, PR, work item, or readable reference
2. Resolve args   -> branch, target, worktree mode, PR tool, checks
3. Branch/worktree-> git worktree add -b ... under .worktrees, or git checkout -b ...
4. Code + commit  -> one logical commit per plan step
5. Verify         -> repo checks plus best-effort native/equivalent checks
6. Fix/queue      -> fix hard blocks, ask plainly on soft blocks, queue reports
7. Draft PR       -> dispatch /quick-pr or /ado-pr
8. Comments       -> post verify summary and unresolved findings
9. Summary        -> branch, commit count, PR URL, /rename hint
```

## Worktree behavior

By default, worktree mode creates generated worktrees under `<repo-root>\.worktrees\<sanitized-branch-name>`. If `.worktrees\` is not ignored in the original checkout, the skill resolves the checkout's local exclude file with `git rev-parse --git-path info/exclude` and asks before adding `.worktrees/` there so the original checkout stays clean. Pass `--worktree-dir DIR` to choose a different parent directory; relative paths resolve from the original repo root and absolute paths are used as-is.

After creating the worktree, the skill moves the session/current working directory to the new worktree root using the runtime's cwd command when available. All subsequent file, search, edit, shell, git, verification, commit, push, and PR operations run from that worktree root, or use paths explicitly rooted at the worktree when a tool cannot inherit the changed cwd.

The skill treats branch names, target names, and worktree paths as untrusted before passing them to shell commands. It prefers argument-safe tool calls and rejects unsafe values rather than interpolating raw user input into command strings.

## Verification behavior

Default checks are repo-provided: `/standards-check`, `/doc-review`, and `/coverage-check` when applicable. The skill also tries available runtime-native review/security/simplification checks or equivalent skills best-effort unless `--skip-native-verify` is set.

The skill prefers a `verify-runner` agent when available so enabled checks can run in parallel; it falls back to direct check execution when the agent is not available. Findings are classified as `hard_block`, `soft_block`, or `report`; hard blocks are fixed before push, soft blocks are fixed or overridden by user choice, and report findings are posted on the PR.

## PR comment fallback

Unresolved findings are posted as line-targeted review comments when possible. If line targeting fails, the skill posts a PR-level comment. If PR posting fails, it writes findings to `~\.agents\verify-findings\` and prints the full path.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No plan found | Pass `--plan-source <file-or-url>` or provide a plan in the session |
| Target branch is wrong | Pass `--target <branch>` |
| PR-tool auto-detection fails | Pass `--pr-tool /quick-pr` or `--pr-tool /ado-pr` |
| Worktree path already exists | Choose `--branch` or `--worktree-dir` with a unique path, or remove the stale worktree |
| `.worktrees\` is not ignored | Approve the local exclude update, pass `--worktree-dir`, or add an ignore rule manually |
| Runtime cwd command is unavailable | Continue only if operations can be explicitly rooted at the worktree path |
| Verify-runner unavailable | The skill falls back to direct checks |
| Branch conflicts with target | Stop and resolve manually; the skill does not auto-resolve conflicts |
