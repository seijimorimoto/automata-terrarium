# Implement Plan

Implements a plan from a session, local file, GitHub issue or PR, or another readable reference. The skill creates an isolated branch or worktree, applies the plan one step at a time with one logical commit per step, runs verification, opens a draft PR, and posts unresolved verify findings.

## Prerequisites

- **Git** — configured with user name and email.

  ```powershell
  git --version
  ```

  ```sh
  git --version
  ```

- **PR-creation skill** — `/quick-pr` for GitHub or `/ado-pr` for Azure DevOps.
- **Verification skills** — `/standards-check` and `/doc-review`; `/coverage-check` is used when a coverage tool is detectable. Runtime-native review/security/simplification checks are optional and enabled with `--try-native-verify-skills`.

## Installation

Install the skill with the sync scripts.

- **Claude project-level** (one project): `<project-root>\.claude\skills\`
- **Claude user-level** (all projects): `~\.claude\skills\`
- **Copilot project-level** (one project): `<project-root>\.github\skills\`
- **Copilot user-level** (all projects): `~\.copilot\skills\`

```powershell
.\bin\seiji-claude-sync-skills.ps1
.\bin\seiji-copilot-sync-skills.ps1
```

```sh
./bin/seiji-claude-sync-skills
# POSIX Copilot sync is tracked by #21.
```

## Usage

```text
/implement
/implement --plan-source plans\dual-runtime-workflow-migration.md
/implement --plan-source https://github.com/owner/repo/issues/123
/implement --branch u/alice/cool-feature --target develop
/implement --no-worktree
/implement --try-native-verify-skills --skip-coverage
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--plan-source` | No | `session` | Session discussion, local file path, GitHub issue/PR URL, or other readable reference |
| `--branch` | No | Generated from project instructions or plan title | Feature branch name |
| `--target` | No | Remote default branch, then `main` | Target branch for the PR |
| `--no-worktree` | No | off | Work in the current tree instead of creating a git worktree |
| `--pr-tool` | No | GitHub -> `/quick-pr`, Azure DevOps -> `/ado-pr` | PR-creation skill |
| `--try-native-verify-skills` | No | off | Also try runtime-native review, security, and simplification checks |
| `--skip-verify` | No | off | Skip all verification |
| `--skip-standards`, `--skip-coverage`, `--skip-doc-review`, `--skip-review`, `--skip-security`, `--skip-simplify` | No | none | Skip individual checks |

## Workflow

```text
1. Read plan      -> session, file, GitHub issue/PR, or readable reference
2. Resolve args   -> branch, target, worktree mode, PR tool, checks
3. Branch/worktree-> git worktree add -b ... or git checkout -b ...
4. Code + commit  -> one logical commit per plan step
5. Verify         -> repo checks by default; optional native checks on request
6. Fix/queue      -> fix hard blocks, ask plainly on soft blocks, queue reports
7. Draft PR       -> dispatch /quick-pr or /ado-pr
8. Comments       -> post verify summary and unresolved findings
9. Summary        -> branch, commit count, PR URL, /rename hint
```

## Verification behavior

Default checks are repo-provided: `/standards-check`, `/doc-review`, and `/coverage-check` when applicable. `--try-native-verify-skills` adds available runtime-native review/security/simplification checks without making them required.

The skill prefers a `verify-runner` agent when available and falls back to direct check execution when it is not. Findings are classified as `hard_block`, `soft_block`, or `report`; hard blocks are fixed before push, soft blocks are fixed or overridden by user choice, and report findings are posted on the PR.

## PR comment fallback

Unresolved findings are posted as line-targeted review comments when possible. If line targeting fails, the skill posts a PR-level comment. If PR posting fails, it writes findings to `~\.agents\verify-findings\` and prints the full path.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No plan found | Pass `--plan-source <file-or-url>` or provide a plan in the session |
| Target branch is wrong | Pass `--target <branch>` |
| PR-tool auto-detection fails | Pass `--pr-tool /quick-pr` or `--pr-tool /ado-pr` |
| Worktree path already exists | Choose `--branch` with a unique name or remove the stale worktree |
| Verify-runner unavailable | The skill falls back to direct checks |
| Branch conflicts with target | Stop and resolve manually; the skill does not auto-resolve conflicts |
