---
name: implement
description: Implement a plan from a session, file, issue, PR, work item, or readable reference with step commits, verification, and a draft PR
argument-hint: "[--plan-source SOURCE] [--branch NAME] [--target BRANCH] [--source BRANCH] [--worktree-dir DIR] [--no-worktree] [--pr-tool NAME] [--skip-native-verify] [--skip-verify] [--skip-standards|--skip-coverage|--skip-doc-review]"
---

# Implement Plan

Implements a plan from the selected source. The workflow creates an isolated branch or worktree, implements the plan one step at a time, commits each logical step, runs repo-provided verification checks by default, opens a draft PR through the selected PR-creation skill, and posts unresolved verify findings back to the PR.

## Usage

```text
/implement
/implement --plan-source plans\feature.md
/implement --plan-source https://github.com/owner/repo/issues/123
/implement --branch u/alice/feature --target develop --no-worktree
/implement --source current
/implement --worktree-dir ..\feature-worktrees
/implement --skip-native-verify --skip-coverage
```

## Parameters

- `--plan-source`: Where to read the plan from. Default: `session`. Supported forms:
  - `session` — use the current conversation.
  - A local file path, or `file:<path>` — read the file from the current repo.
  - An issue, PR, work item, or other readable URL/reference — read the title/body and relevant comments with the available local, CLI, web, or MCP tools.
  - Any other readable reference — use the available local, web, or MCP reader. If it cannot be read, stop with the failed reference.
- `--branch`: Feature branch name. If omitted, read project instructions (`AGENTS.md`, `CLAUDE.md`, `.github\copilot-instructions.md`, and linked instruction files) for a branch naming convention. If none exists, use `{alias}/{short-kebab-case-feature-title}`, where `{alias}` is the part before `@` in `git config user.email`.
- `--target`: Target branch for the PR. Default: `git symbolic-ref refs/remotes/origin/HEAD --short` with `origin/` stripped; falls back to `main`.
- `--source`: Branch/ref to base the new implementation branch on. Default: the resolved `--target`. Use `--source current` to base it on the current branch/HEAD for stacked work.
- `--worktree-dir`: Parent directory for the generated worktree folder. Relative paths are resolved from the original repo root. Default: `.worktrees`.
- `--no-worktree`: Work directly in the current working tree. By default, create a git worktree for isolation.
- `--pr-tool`: PR-creation skill to dispatch to. Default: auto-detect from `git remote get-url origin`.
- `--skip-native-verify`: Skip best-effort runtime-native or equivalent review, security, and simplification checks.
- `--skip-verify`: Skip all verification checks.
- `--skip-standards`, `--skip-coverage`, `--skip-doc-review`: Skip individual repo-provided checks.

## Instructions

When this skill is invoked:

### 1. Read the plan

Resolve `--plan-source` before changing files.

- For `session`, use the implementation plan already discussed in the conversation. If no actionable plan exists, say: "No implementation plan found in this session. Provide a plan or pass `--plan-source <file-or-url>`."
- For local paths, read the file and treat its ordered steps as the implementation plan.
- For GitHub issue or PR URLs, use `gh issue view` or `gh pr view` to read the title, body, and comments that materially change the plan.
- For Azure DevOps work item or PR references, use the available Azure DevOps CLI or MCP tools to read the title, body, comments, and linked context that materially change the plan.
- For other readable references, use the available local, web, or MCP tools. Do not guess at unreadable content.

Extract a short feature title and an ordered step list. If the source is prose rather than numbered steps, derive a practical ordered checklist before coding.

### 2. Resolve branch, target, worktree, PR tool, and checks

- Resolve `--target` from the flag, then `origin/HEAD`, then `main`.
- Resolve `--source` from the flag, then the resolved `<target>`. If `--source current` is set, resolve it to the current branch name, or `HEAD` when detached. This default keeps new work based on the PR target branch; stacked work from the current branch must be explicit.
- Resolve `--branch` from the flag, then project instructions, then `{alias}/{short-kebab-case-feature-title}`.
- Treat resolved branch names, source refs, target names, and worktree paths as untrusted before passing them to shell commands. Prefer argument-safe tool calls. If only shell commands are available, reject branch, source, and target names that start with `-` or contain characters outside `[A-Za-z0-9._/-]`; reject paths containing quotes, control characters, or shell metacharacters. Do not concatenate raw user input into shell commands.
- Resolve `--pr-tool` from the flag or this table:

  | Remote URL contains | Default PR-creation skill | Required interface |
  | --- | --- | --- |
  | `github.com` | `/quick-pr` | Accepts `--draft`, `--target` or `--base`, and `--no-merge` |
  | `dev.azure.com` or `visualstudio.com` | `/ado-pr` | Accepts `--draft` and `--target` |

  If no mapping matches, ask plainly which PR skill to use and wait for the answer.
- Build the verify check list:
  - Default checks: `/standards-check`, `/doc-review`, and `/coverage-check` when a project coverage tool is detectable.
  - Remove checks skipped by `--skip-<check>`.
  - Unless `--skip-native-verify` is set, add runtime-native `/review`, `/security-review`, `/simplify`, or any other equivalent available skills only when they are available in the current runtime.

Before coding, compare `<source>` to `<target>` unless they resolve to the same commit. If the source already has merge conflicts with `<target>`, stop and inform the user; do not force-push or auto-resolve.

### 3. Create the branch or worktree

- Default worktree mode:
  1. Sanitize the branch name for a folder by replacing `/` with `-`.
  2. Resolve the worktree parent directory:
     - If `--worktree-dir` is set, use that directory. Resolve relative paths from the original repo root and absolute paths as-is.
     - Otherwise, use `<repo-root>\.worktrees`.
  3. If the default `.worktrees\` parent is not ignored in the original checkout, resolve the checkout's local exclude file with `git rev-parse --git-path info/exclude`, then ask before adding `.worktrees/` there. Do not assume `.git\info\exclude` exists, because linked worktrees use a `.git` file. Do not modify tracked `.gitignore` in the original checkout before creating the worktree because that dirties the tree the worktree is meant to isolate. If the user declines, stop and ask them to choose `--worktree-dir` or add an ignore rule manually.
  4. Choose `<worktree-parent>\<sanitized-worktree-name>` unless that path is occupied. If the parent path is occupied by a file, or the generated worktree path already exists, stop and report the path conflict.
  5. Run the argument-safe equivalent of `git worktree add -b <branch-name> <worktree-path> <source>`.
  6. Move the session/current working directory to `<worktree-path>` using the runtime's cwd command when available, then confirm `git rev-parse --show-toplevel` resolves to `<worktree-path>`. Runtime examples: Copilot CLI supports `/cwd <worktree-path>` or `/cd <worktree-path>`; Claude Code supports `/cd <worktree-path>` on supported versions.
  7. Run all subsequent file, search, edit, shell, git, verify, commit, push, and PR operations from the new worktree. If a tool cannot inherit the changed cwd, root that tool call at `<worktree-path>` or use an argument-safe `git -C <worktree-path> ...` invocation.
- `--no-worktree` mode:
  1. Run the argument-safe equivalent of `git checkout -b <branch-name> <source>`.
  2. Work in the current tree.

If branch creation fails because the branch already exists, inspect where it is checked out and continue only when doing so is safe and unambiguous.

### 4. Implement one step at a time

For each plan step:

1. Announce the step before starting it.
2. Make only the changes required for that step.
3. Verify the step where practical with existing repo commands, targeted tests, dry-runs, or validation scripts.
4. Fix failures before committing.
5. Stage only the files for that step; do not use `git add -A` or `git add .`.
6. Commit one logical unit using the project's commit-message convention. Use single quotes around commit messages.

### 5. Run the verify phase

Skip this section when `--skip-verify` is set.

Prefer a `verify-runner` agent when one is available in the current runtime. Use it to run the N enabled checks in parallel when the runtime supports parallel agent calls. If not available, run the enabled check skills directly. Either path must return each check's raw output and preserve JSON schemas:

- `/standards-check`, `/doc-review`, `/review`, `/security-review`, and `/simplify` return a JSON array.
- `/coverage-check` returns `{ "summary": ..., "findings": [...] }`.

Classify findings by `tier`:

- `hard_block` — must fix before push.
- `soft_block` — ask the user in plain text to choose `Fix`, `Override`, or `Abort`.
- `report` — queue for PR comments without changing code.

Resolve findings:

- Fix hard blocks in place.
- For soft blocks, ask a concise plain text question containing the message and file/line when present. `Fix` applies the change, `Override` queues the finding for the PR, and `Abort` stops the workflow.
- For coverage soft blocks, write tests for `pure_logic` and `trivial`, propose an exclusion comment for `untestable`, and add the project coverage exclusion marker for `generated`.
- Commit verify fixes as `fix(review): address verify findings`.
- Re-run only checks whose findings produced fixes.
- Stop after 3 outer iterations. Coverage-specific fixing is capped at 2 iterations. If hard blocks remain at the cap, ask whether to continue anyway or abort; continuing demotes those findings to PR comments.

### 6. Push, create the draft PR, and post verify output

1. Push the branch with the argument-safe equivalent of `git push -u origin <branch-name>`.
2. Create a draft PR through the selected PR skill:
   - GitHub: `/quick-pr --draft --target <target-branch> --no-merge` (or the runtime-equivalent invocation).
   - Azure DevOps: `/ado-pr --draft --target <target-branch>`.
3. Post verify output directly with `gh`, `az`, or MCP tools. Do not delegate comments to the PR-creation skill.

Post one PR-level verify summary:

```markdown
## Verify summary
Ran <N> checks in parallel: <comma-separated list>.
- Hard-blocks fixed: <count>
- Soft-blocks fixed: <count>
- Soft-blocks overridden: <count>
- Report-only findings posted as comments: <count>
- Findings posted as text (line-targeting failed): <count>
- Findings written to file (posting failed): <count>
```

If the summary is posted through an API that creates a resolvable review thread, mark that summary thread resolved or closed immediately because it is awareness-only.

Post each unresolved finding with this fallback chain:

1. Line-targeted PR review comment when `file` and `line` are valid and inside the diff.
2. PR-level comment prefixed with `<file>:<line>` when line targeting fails or is unavailable.
3. File fallback under `~\.agents\verify-findings\<owner>-<repo>-pr-<n>-<ISO timestamp>.md`.

If anything uses the file fallback, print the full fallback path.

### 7. Finish

Display the branch name, number of commits created by this run, and PR URL. Print a copiable session rename command for the user: `/rename PR #<number>: <title>`.

## Error handling

- No plan found or unreadable `--plan-source`: stop before changing files.
- Target auto-detection failure: fall back to `main` and mention the fallback.
- Source resolution failure or missing source ref: stop before creating the branch.
- PR-tool auto-detection failure: ask plainly which PR skill to use.
- Verify-runner unavailable: fall back to direct checks.
- Verify output is non-JSON or a check errors: convert that check result into one `report` finding and continue.
- Default `.worktrees\` is not ignored and the user declines the local exclude update: stop and ask for `--worktree-dir` or a manual ignore rule.
- Worktree cwd switch is unavailable: continue only if every subsequent file, shell, git, verify, commit, push, and PR operation can be explicitly rooted at the worktree path.
- Merge conflicts with target, build failures, or unsafe branch/worktree state: stop and report the blocker.
