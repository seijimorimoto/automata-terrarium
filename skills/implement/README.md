# Implement Plan

After a plan has been approved (e.g., via plan mode), `/implement` carries it out: creates a feature branch (or worktree), implements each step with auto-edits, makes one logical commit per step, runs a parallel **verify phase** (standards / review / security / doc-review / simplify / coverage), iterates on the findings, and opens a draft PR with the unresolved findings posted as review comments.

## Prerequisites

- **A plan in the current session.** `/implement` only runs after a plan has been presented in the same conversation — typically via plan mode, but a manually written numbered step list works too.
- **Git** — configured with user name and email.
- **A PR-creation skill installed** for the remote you're working against:
  - GitHub repos: `/quick-pr` (default)
  - Azure DevOps repos: `/ado-pr` (default)
  - Override the default with `--pr-tool`.
- **The verify-runner agent** at `~/.claude/agents/verify-runner.md` (synced from this repo's `agents/`). Required unless you run with `--skip-verify`.
- **The verify checks the verify phase calls.** Required unless skipped:
  - `/standards-check`, `/doc-review`, `/coverage-check` (in this repo's `skills/`)
  - `/review`, `/security-review`, `/simplify` (Anthropic-shipped Claude Code skills, available by default)
- **Optional:** the `verify-runner-bash-guard` hook (this repo's `hooks/`) for runtime Bash restriction inside the verify-runner subagent. Without it, the verify-runner relies on prompt-level discipline plus its tool-list restrictions; that's a documented acceptable v1 floor.

## Installation

Copy the skill folder to either location:

- **Project-level** (one project): `<project-root>\.claude\skills\`
- **User-level** (all projects): `~\.claude\skills\`

```powershell
# Windows (PowerShell)

# Project-level
Copy-Item -Recurse skills\implement <your-project>\.claude\skills\

# User-level
Copy-Item -Recurse skills\implement ~\.claude\skills\

# Or symlink (project-level)
New-Item -ItemType SymbolicLink -Path <your-project>\.claude\skills\implement -Target (Resolve-Path skills\implement)
```

```sh
# Linux / macOS
cp -r skills/implement <your-project>/.claude/skills/    # project-level
cp -r skills/implement ~/.claude/skills/                 # user-level
ln -s "$(pwd)/skills/implement" <your-project>/.claude/skills/implement  # symlink
```

If you're using the `bin/seiji-claude-sync` infrastructure in this repo, just run `seiji-claude-sync` and `/implement` will land at the user level along with every other skill.

## Permissions

This skill orchestrates `git`, `gh`/`az`, and your PR-creation skill of choice; it does not introduce permissions of its own. Add permissions from these presets to your Claude Code settings to avoid prompts:

- [`settings/base.json`](../../settings/base.json) — git operations
- [`settings/github.json`](../../settings/github.json) — `gh` (when using `/quick-pr`)
- [`settings/ado.json`](../../settings/ado.json) — `az` (when using `/ado-pr`)

## Usage

```bash
/implement                                                   # use defaults: auto-detect target + PR tool
/implement --branch u/alice/cool-feature                     # custom branch name
/implement --target develop                                  # target a non-default branch
/implement --no-worktree                                     # work in current tree, skip worktree
/implement --pr-tool /ado-pr                                 # force a specific PR-creation skill
/implement --branch u/alice/cool-feature --target develop    # combine flags
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--branch` | No | Auto-generated from the plan, following any naming convention in the project's CLAUDE.md (otherwise `{alias}/{short-kebab-case}`) | Feature branch name |
| `--target` | No | `git symbolic-ref refs/remotes/origin/HEAD` (typically `main`); falls back to `main` | Target branch for the PR |
| `--no-worktree` | No | `false` (worktrees on by default) | Skip worktree isolation; work directly in the current tree |
| `--pr-tool` | No | Auto-detected from origin URL: GitHub → `/quick-pr`, ADO → `/ado-pr` | PR-creation skill to dispatch to |
| `--skip-verify` | No | `false` (verify runs by default) | Skip the entire verify phase |
| `--skip-standards`, `--skip-coverage`, `--skip-review`, `--skip-security`, `--skip-doc-review`, `--skip-simplify` | No | none | Skip individual verify checks; combinable |

## Workflow

```
1. Find plan      →  Look back through the conversation for a plan
2. Resolve args   →  Decide branch, target, worktree, PR tool, skips up front
3. Plan file      →  Prepend a concrete instruction block (no templates)
4. ExitPlanMode   →  Hand off to a fresh implementation context
5. Branch / WT    →  Create worktree (default) or branch (--no-worktree)
6. Code + commit  →  One logical commit per step, no `git add -A`
7. Verify         →  Spawn verify-runner subagents in parallel (skipped on --skip-verify):
                     /standards-check, /review, /security-review,
                     /doc-review, /simplify, /coverage-check.
                     Classify findings (hard_block / soft_block / report),
                     auto-fix or AskUserQuestion, re-run addressed checks.
                     Cap: 3 outer iterations, 2 for the coverage sub-loop.
                     Auto-fixes commit as 'fix(review): address verify findings'.
8. Push           →  git push -u origin <branch>
9. Draft PR       →  Dispatch to <pr-tool> --draft --target <target>
10. Verify summary →  Update PR description with finding counts.
11. PR comments   →  Post unresolved report-only findings as review comments
                     (line-targeted via gh/az/MCP; falls back to PR-level
                     and then to PR-description text if APIs reject).
12. Summary       →  Print branch, commit count, PR URL, /rename hint
```

## Customization

### Personal `/rename` reminder

The default workflow prints a copiable `/rename PR #<n>: <title>` command at the end. `/rename` is a personal-workflow shortcut that only the user can run (not Claude). If you don't use `/rename`, delete the "Print a copiable command…" bullet from `SKILL.md`'s "After coding" section.

### Adding a new PR-creation skill

The auto-detection table in `SKILL.md` maps remote URL patterns to PR-creation skills. To register a new one:

1. Add a row to the table in `SKILL.md` with the URL pattern and the new skill's slash name.
2. Confirm the new skill accepts a `--draft` flag and a `--target`/`--base` flag for the target branch (or document the exact flag set in the table).

`/implement` does not modify the dispatched skills' behavior — they're invoked unchanged. Comment-posting on the resulting PR is done directly from `/implement` (see the verify phase docs once that lands), so PR-creation skills don't need to know anything about line-level review comments.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No implementation plan found in this session" | Create a plan first (plan mode, or paste a numbered step list) and re-run `/implement` |
| Auto-detected target is wrong | Pass `--target <branch>` explicitly |
| PR-tool auto-detection fails (unknown remote host) | Pass `--pr-tool </name-of-skill>` and add a row to the auto-detection table in `SKILL.md` |
| EnterWorktree refuses ("already inside a worktree") | You're nested. Either `cd` to the main checkout first, or use `--no-worktree` |
| Build/test fails partway through | Fix in-place and amend into the same step's commit before moving to the next step |
| Branch has merge conflicts with target | Stop and resolve manually — `/implement` will not auto-resolve or force-push |
