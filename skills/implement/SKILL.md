---
name: implement
description: Implement a plan from the current session — creates a branch, codes with auto-edits, commits each step, runs a parallel verify phase (standards, review, security, doc-review, simplify, coverage), and opens a draft PR
argument-hint: "[--branch NAME] [--target BRANCH] [--no-worktree] [--pr-tool NAME] [--skip-verify] [--skip-standards|--skip-coverage|--skip-review|--skip-security|--skip-doc-review|--skip-simplify]"
---

# Implement Plan

Implements a plan that was created earlier in the current Claude Code session. Enters "Edit automatically" mode, creates a feature branch (or uses a worktree by default), makes logical commits at each step, runs a **verify phase** that spawns parallel `verify-runner` subagents for `/standards-check`, `/review`, `/security-review`, `/doc-review`, `/simplify`, and (when applicable) `/coverage-check`, iterates on the findings, and finishes by opening a draft PR via the selected PR-creation skill — with the unaddressed findings posted as PR review comments.

## Usage

```
/implement [--branch NAME] [--target BRANCH] [--no-worktree] [--pr-tool NAME]
           [--skip-verify]
           [--skip-standards] [--skip-coverage] [--skip-review]
           [--skip-security] [--skip-doc-review] [--skip-simplify]
```

## Parameters

- `--branch`: Branch name to create (default: auto-generated from the plan summary, following any branch naming convention defined in the project's CLAUDE.md; if none is defined, uses `{alias}/{short-kebab-case-feature-title}` where `{alias}` is the part before `@` from `git config user.email`).
- `--target`: Target branch for the eventual PR. Default: auto-detected from `git symbolic-ref refs/remotes/origin/HEAD` (typically `main` or `master`). Falls back to `main` if the symbolic ref isn't set.
- `--no-worktree`: Skip worktree creation and work directly in the current working tree (default behavior is to use a git worktree for isolation).
- `--pr-tool`: PR-creation skill to dispatch to (e.g., `/quick-pr`, `/ado-pr`). Default: auto-detected from `git remote get-url origin` — GitHub → `/quick-pr`, Azure DevOps → `/ado-pr`. The mapping is extensible; new PR-creation skills can be added by extending the auto-detection table in this file.
- `--skip-verify`: Skip the entire verify phase. The default behavior is to run it.
- `--skip-standards`, `--skip-coverage`, `--skip-review`, `--skip-security`, `--skip-doc-review`, `--skip-simplify`: Skip a specific verify check. Multiple may be combined.

## Instructions

When this skill is invoked:

1. **Find the plan.** Look back through the current conversation for a plan that was presented to the user (e.g., via plan mode, a numbered step list, or an explicit implementation plan). If **no plan is found**, inform the user:
   > "No implementation plan found in this session. Please create a plan first (e.g., using /plan or by asking me to plan the implementation), then invoke /implement."

2. **Resolve every argument up front.** Do not write conditional templates into the plan file — write a concrete instruction block. Resolve as follows:

   - **`--branch`** — if provided, use it. Otherwise:
     1. Read CLAUDE.md (project-root, then user-level) and look for a branch-naming convention.
     2. If found, derive a branch name from the plan summary that matches the convention.
     3. Otherwise default to `{alias}/{short-kebab-case-feature-title}` where `{alias}` is the part before `@` in `git config user.email`.

   - **`--target`** — if provided, use it. Otherwise run `git symbolic-ref refs/remotes/origin/HEAD --short` and take the part after `origin/` (e.g., `origin/main` → `main`). If the symbolic ref isn't set, fall back to `main`.

   - **`--no-worktree`** — boolean. If absent (default), the implementation will use a git worktree.

   - **`--pr-tool`** — if provided, use it. Otherwise auto-detect from `git remote get-url origin`:

     | Remote URL contains | Default PR-creation skill |
     | --- | --- |
     | `github.com` | `/quick-pr` |
     | `dev.azure.com` or `visualstudio.com` | `/ado-pr` |

     If neither pattern matches, ask the user which PR-creation skill to use. To add a new PR-creation skill, extend this table when promoting that skill into the repo.

3. **Prepare the plan file.** Read the plan file used by plan mode to check its current contents.
   - If the plan file already contains the plan, **prepend** the implementation workflow instructions (see template below) to the existing plan content, with all placeholders replaced by the concrete values resolved in step 2.
   - If the plan file does not contain the plan (e.g., the plan was discussed conversationally rather than through plan mode), write **both** the resolved implementation workflow instructions and the complete plan (all steps, context, file paths, and relevant details) to the plan file.

4. **Start a fresh context.** Use **ExitPlanMode** to transition into a fresh context window for implementation — just like the native plan mode flow.

  The implementation workflow template to write into the plan file (with placeholders `<branch-name>`, `<target-branch>`, `<pr-tool>`, and the worktree paragraph chosen by the resolved `--no-worktree` flag, all substituted before write):

  ```
  # Implementation Workflow

  Follow these steps to implement the plan below. Edit files automatically without asking for confirmation on each change — the user has opted in.

  ## Before coding
  - Branch name: `<branch-name>`
  - Target branch for PR: `<target-branch>`
  - PR-creation skill: `<pr-tool>`

  [If worktree mode (default — `--no-worktree` was NOT provided), include this paragraph:]

  - **Create a worktree** for isolated development using the **EnterWorktree** tool.
  - Worktree name (branch with `/` replaced by `-`): `<sanitized-worktree-name>`
  - Call `EnterWorktree` with that sanitized name.
  - After entering the worktree, **rename the auto-created branch** to `<branch-name>`: `git branch -m <branch-name>`.
  - All subsequent work (coding, commits, push, PR) happens inside this worktree.

  [If `--no-worktree` was provided, include this paragraph instead:]

  - Create a new git branch for this work: `git checkout -b <branch-name>`.
  - Work directly in the current working tree.

  ## While coding
  - Implement each step of the plan below **one at a time**.
  - **Announce** each step before starting it (e.g., "Step 1: Add the new model classes").
  - After completing each step, verify it compiles/is correct where practical (e.g., `dotnet build` for .NET projects).
  - If a build fails, fix the issue before committing. Include the fix in the same commit as the step that caused the failure.
  - Commit each step as a **separate logical commit**:
    - Each commit should represent **one logical unit of work** — not one file, and not the entire plan.
    - If a step touches many files that belong together logically, commit them together.
    - Stage only the specific files for that step (`git add <files>`) — never use `git add -A` or `git add .`.
    - Follow the commit message conventions in the project's CLAUDE.md. If none are defined, use Conventional Commits.
    - Use single quotes around commit messages to avoid shell expansion issues.
  - If the branch has merge conflicts with `<target-branch>`, **stop and inform the user** — do not force-push or auto-resolve.

  ## Verify phase

  [If `--skip-verify` was provided, omit this whole section.]

  After the last per-step commit and before pushing, run the verify phase: spawn parallel `verify-runner` subagents to run quality checks against the diff, classify their findings, auto-fix confident ones, prompt for soft-blocks, and queue report-only findings for posting as PR comments after the PR is opened.

  **Active checks for this run:** <comma-separated list of enabled skills, e.g., `/standards-check`, `/review`, `/security-review`, `/doc-review`, `/simplify`, `/coverage-check` — omit any disabled by `--skip-<check>` flags. `/coverage-check` is included only when a coverage tool is detectable for the project.>

  ### Per-iteration flow

  1. **Spawn subagents in parallel.** In a single message, issue one `Agent` call per active check. Each:
     - `subagent_type: "verify-runner"`
     - `description`: short, e.g., `"Run /standards-check on the diff"`
     - `prompt`: a self-contained instruction along these lines:
       ```
       Run /<skill-name> against the current diff. The target branch is
       <target-branch>. Pass --target <target-branch> to the skill.

       Return the skill's stdout verbatim — no prose, no markdown fences,
       no rewriting of its schema. Most skills emit a JSON array of
       findings; /coverage-check emits { "summary": {...}, "findings":
       [...] }. If there are no findings, forward whatever empty form
       the skill produced ([] or { "summary": null, "findings": [] }).
       ```

  2. **Collect findings.** From each subagent's response, extract the findings list. For skills emitting a JSON array (`/standards-check`, `/review`, `/security-review`, `/doc-review`, `/simplify`), the response *is* the list. For `/coverage-check`, read `findings` out of the `{summary, findings}` object and stash `summary` separately (used in step 4 for the coverage sub-loop and in the verify-summary). Each finding carries an implicit "source" tag — the skill it came from — by virtue of which subagent returned it.

  3. **Classify by tier.**
     - `hard_block` → must fix before push.
     - `soft_block` → fix or override per finding via `AskUserQuestion`.
     - `report` → set aside for PR comments.

  4. **Resolve.**
     - **Hard blocks.** Fix in-place. Stage the fix.
     - **Soft blocks.** For each, call `AskUserQuestion` with a short version of the finding's `message` (plus file/line if present). Options: `Fix` (auto-fix), `Override` (proceed without fixing — the finding moves to the PR-comment queue), `Abort` (stop /implement).
       - For coverage `soft_block` findings, the auto-fix path branches on `chunk_kind`:
         - `pure_logic` and `trivial` → write tests.
         - `untestable` → propose adding an exclusion comment with rationale; user confirms.
         - `generated` → add the project's coverage-tool exclusion marker (`# pragma: no cover`, `// istanbul ignore next`, `[ExcludeFromCodeCoverage]`, etc.).
       - The coverage sub-loop is capped at **2 iterations** independent of the outer cap.
     - **Report findings.** Queue for PR comments. Do not modify code.

  5. **Commit auto-fixes.** Stage all changes from this iteration and commit:
     ```
     git add <specific files>
     git commit -m 'fix(review): address verify findings'
     ```
     Use single quotes per the repo's CLAUDE.md.

  6. **Re-run only addressed checks.** Spawn a new parallel batch of verify-runner subagents — but only for the checks whose findings produced fixes in this iteration. Skip checks whose findings were unchanged (still pending PR comments) or whose findings were `Override`d.

  7. **Iteration cap.** Stop after **3 outer iterations**. If hard-blocks remain at the cap, surface them via `AskUserQuestion` (`Continue Anyway` / `Abort`). If the user picks Continue, those hard-blocks demote to `report` and ride along as PR comments.

  ## After coding
  - Push the branch: `git push -u origin <branch-name>`
  - Create a **draft** PR via `<pr-tool> --draft --target <target-branch>` (or the equivalent flag set for the chosen PR-creation skill).
  - **Post verify outputs as PR comments** directly via `gh` / `az` / MCP. Do **not** dispatch this to the PR-creation skill — keep that skill focused on PR creation.

    **(a) Verify-summary as a PR-level (overall) comment.** One comment containing:

    ```
    ## Verify summary
    Ran <N> checks in parallel: <comma-separated list of skills run>.
    - Hard-blocks fixed: <count>
    - Soft-blocks fixed:  <count>
    - Soft-blocks overridden: <count>
    - Report-only findings posted as comments: <count>
    - Findings posted as text (line-targeting failed): <count>
    - Findings written to file (posting failed): <count>
    ```

    If a check was skipped (e.g., `--skip-coverage`), say so explicitly: `Coverage skipped (--skip-coverage)`.

    Posting commands:
    - GitHub: `gh pr comment <pr> --body '<body>'` (the issue/conversation comment, not a review comment)
    - Azure DevOps: `az repos pr comment add` or `mcp__ado__repo_create_pr_thread` (PR-level thread)

    **(b) Each unresolved report-only finding as a line-targeted review comment**, with this fallback chain:

    1. **Line-targeted comment.** Requires valid `file` + `line` AND that line being inside the PR's diff.
       - GitHub: `gh api repos/:owner/:repo/pulls/:pr/comments` with `path`, `line`, `commit_id`, `body`. GitHub MCP if installed.
       - Azure DevOps: `az repos pr comment add --thread-context file:line` or ADO MCP `mcp__ado__repo_create_pr_thread` equivalent.
    2. **PR-level overall comment** for the same finding, using the same posting command as the verify-summary. In the body, prefix with the `<file>:<line>` so the original target isn't lost.
    3. **File fallback.** Append the finding to `~/.claude/verify-findings/<owner>-<repo>-pr-<n>-<ISO timestamp>.md` (create the directory if needed). One file per /implement run; one section per finding with file/line, source skill, message.

    The verify-summary itself follows the same chain starting at step 2 (it's not line-scoped): PR-level → file.

    After all postings finish, if any findings ended up in the file fallback, print the file's full path so the user can find them.

  - Display a summary: branch name, number of commits, and PR URL.
  - Print a copiable command for the user to rename the session: `/rename PR #<number>: <title>` (use the PR number and title from the PR you just created). Note: `/rename` is a built-in CLI command that only the user can execute — Claude cannot run it programmatically.

  ---

  ```

  **Important:** All placeholders (`<branch-name>`, `<target-branch>`, `<pr-tool>`, `<sanitized-worktree-name>`) must be replaced with concrete values **before** writing to the plan file. The bracketed worktree-mode/no-worktree paragraph picks one and only one based on whether the user passed `--no-worktree`. The plan content follows after the `---` separator.

## Verify checks reference

| Check | Skill | Default tier of findings |
|-------|-------|--------------------------|
| Standards | `/standards-check` | `hard_block` for mechanical+high-conf; else `soft_block` or `report` |
| Review | `/review` | `report` |
| Security | `/security-review` | `soft_block` |
| Doc review | `/doc-review` | `report` |
| Simplify | `/simplify` | `report` |
| Coverage | `/coverage-check` | `soft_block` if threshold below; else `report` |

The verify phase's full per-iteration flow and PR-comment posting fallback chain (line-targeted → PR-level → file) are inlined in the workflow template above so the plan-file reader has everything it needs without consulting this file.

## Error Handling

- **No plan found**: Exit early with a clear message (see step 1).
- **Auto-detection of `--target` fails** (no `origin/HEAD`, no remote configured): fall back to `main` and print a notice. The user can override with `--target`.
- **Auto-detection of `--pr-tool` fails** (remote URL doesn't match any known host): ask the user which PR-creation skill to use rather than silently defaulting.
- **A verify-runner subagent fails or returns non-JSON.** Treat as a single `report`-tier finding with `message: "verify-runner: <skill> returned no JSON or errored: <reason>"`. Continue with the remaining checks.
- **Verify cap reached with hard-blocks remaining.** Surface via `AskUserQuestion` (`Continue Anyway` / `Abort`). On Continue, demote remaining hard-blocks to PR comments.
- All other error handling (build failures, merge conflicts) is covered in the workflow instructions written to the plan file.

## Examples

Implement the plan discussed in the current session:
```
/implement
```

Implement with a custom branch name:
```
/implement --branch johndoe/add-digest-email
```

Implement targeting a different branch:
```
/implement --target develop
```

Implement without worktree isolation (work directly in the current tree):
```
/implement --no-worktree
```

Implement on a GitHub repo but force a different PR-creation skill:
```
/implement --pr-tool /ado-pr
```

Combine flags:
```
/implement --branch johndoe/add-digest-email --target develop --no-worktree
```

Skip the verify phase entirely (e.g., for a one-line typo fix):
```
/implement --skip-verify
```

Skip individual verify checks:
```
/implement --skip-coverage --skip-doc-review
```
