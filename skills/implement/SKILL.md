---
name: implement
description: Implement a plan from a session, file, issue, PR, or readable reference with step commits, verification, and a draft PR
argument-hint: "[--plan-source SOURCE] [--branch NAME] [--target BRANCH] [--no-worktree] [--pr-tool NAME] [--try-native-verify-skills] [--skip-verify] [--skip-standards|--skip-coverage|--skip-doc-review|--skip-review|--skip-security|--skip-simplify]"
---

# Implement Plan

Implements a plan from the selected source. The workflow creates an isolated branch or worktree, implements the plan one step at a time, commits each logical step, runs repo-provided verification checks by default, opens a draft PR through the selected PR-creation skill, and posts unresolved verify findings back to the PR.

## Usage

```text
/implement
/implement --plan-source plans\feature.md
/implement --plan-source https://github.com/owner/repo/issues/123
/implement --branch u/alice/feature --target develop --no-worktree
/implement --try-native-verify-skills --skip-coverage
```

## Parameters

- `--plan-source`: Where to read the plan from. Default: `session`. Supported forms:
  - `session` — use the current conversation.
  - A local file path, or `file:<path>` — read the file from the current repo.
  - A GitHub issue or PR URL — read the title/body and relevant comments with `gh`.
  - Any other readable reference — use the available local, web, or MCP reader. If it cannot be read, stop with the failed reference.
- `--branch`: Feature branch name. If omitted, read project instructions (`AGENTS.md`, `CLAUDE.md`, `.github\copilot-instructions.md`, and linked instruction files) for a branch naming convention. If none exists, use `{alias}/{short-kebab-case-feature-title}`, where `{alias}` is the part before `@` in `git config user.email`.
- `--target`: Target branch for the PR. Default: `git symbolic-ref refs/remotes/origin/HEAD --short` with `origin/` stripped; falls back to `main`.
- `--no-worktree`: Work directly in the current working tree. By default, create a git worktree for isolation.
- `--pr-tool`: PR-creation skill to dispatch to. Default: auto-detect from `git remote get-url origin`.
- `--try-native-verify-skills`: Best-effort opt-in for runtime-native review, security, and simplification checks in addition to repo-provided checks.
- `--skip-verify`: Skip all verification checks.
- `--skip-standards`, `--skip-coverage`, `--skip-doc-review`, `--skip-review`, `--skip-security`, `--skip-simplify`: Skip individual checks. Review/security/simplify skips only matter when `--try-native-verify-skills` is enabled or those checks are otherwise available.

## Instructions

When this skill is invoked:

### 1. Read the plan

Resolve `--plan-source` before changing files.

- For `session`, use the implementation plan already discussed in the conversation. If no actionable plan exists, say: "No implementation plan found in this session. Provide a plan or pass `--plan-source <file-or-url>`."
- For local paths, read the file and treat its ordered steps as the implementation plan.
- For GitHub issue or PR URLs, use `gh issue view` or `gh pr view` to read the title, body, and comments that materially change the plan.
- For other readable references, use the available local, web, or MCP tools. Do not guess at unreadable content.

Extract a short feature title and an ordered step list. If the source is prose rather than numbered steps, derive a practical ordered checklist before coding.

### 2. Resolve branch, target, worktree, PR tool, and checks

- Resolve `--target` from the flag, then `origin/HEAD`, then `main`.
- Resolve `--branch` from the flag, then project instructions, then `{alias}/{short-kebab-case-feature-title}`.
- Resolve `--pr-tool` from the flag or this table:

  | Remote URL contains | Default PR-creation skill | Required interface |
  | --- | --- | --- |
  | `github.com` | `/quick-pr` | Accepts `--draft`, `--target` or `--base`, and a no-merge option |
  | `dev.azure.com` or `visualstudio.com` | `/ado-pr` | Accepts `--draft` and `--target` |

  If no mapping matches, ask plainly which PR skill to use and wait for the answer.
- Build the verify check list:
  - Default checks: `/standards-check`, `/doc-review`, and `/coverage-check` when a project coverage tool is detectable.
  - Remove checks skipped by `--skip-<check>`.
  - If `--try-native-verify-skills` is enabled, add runtime-native `/review`, `/security-review`, and `/simplify` only when they are available in the current runtime.

Before coding, compare the current branch to `<target>`. If there are merge conflicts with `<target>`, stop and inform the user; do not force-push or auto-resolve.

### 3. Create the branch or worktree

- Default worktree mode:
  1. Sanitize the branch name for a folder by replacing `/` with `-`.
  2. Choose a sibling worktree path such as `..\worktrees\<sanitized-worktree-name>` unless that path is occupied.
  3. Run `git worktree add -b '<branch-name>' '<worktree-path>' '<target-branch>'`.
  4. Run all subsequent commands inside the new worktree.
- `--no-worktree` mode:
  1. Run `git checkout -b '<branch-name>'`.
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

Prefer a `verify-runner` agent when one is available in the current runtime. If not available, run the enabled check skills directly. Either path must return each check's raw output and preserve JSON schemas:

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

1. Push the branch: `git push -u origin '<branch-name>'`.
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
- PR-tool auto-detection failure: ask plainly which PR skill to use.
- Verify-runner unavailable: fall back to direct checks.
- Verify output is non-JSON or a check errors: convert that check result into one `report` finding and continue.
- Merge conflicts with target, build failures, or unsafe branch/worktree state: stop and report the blocker.
