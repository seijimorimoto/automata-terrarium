---
name: implement
description: Implement a plan from the current session — creates a branch, codes with auto-edits, commits each step, and opens a draft PR
argument-hint: "[--branch NAME] [--target BRANCH] [--no-worktree] [--pr-tool NAME]"
---

# Implement Plan

Implements a plan that was created earlier in the current Claude Code session. Enters "Edit automatically" mode, creates a feature branch (or uses a worktree by default), makes logical commits at each step, and finishes by opening a draft PR via the selected PR-creation skill.

## Usage

```
/implement [--branch NAME] [--target BRANCH] [--no-worktree] [--pr-tool NAME]
```

## Parameters

- `--branch`: Branch name to create (default: auto-generated from the plan summary, following any branch naming convention defined in the project's CLAUDE.md; if none is defined, uses `{alias}/{short-kebab-case-feature-title}` where `{alias}` is the part before `@` from `git config user.email`).
- `--target`: Target branch for the eventual PR. Default: auto-detected from `git symbolic-ref refs/remotes/origin/HEAD` (typically `main` or `master`). Falls back to `main` if the symbolic ref isn't set.
- `--no-worktree`: Skip worktree creation and work directly in the current working tree (default behavior is to use a git worktree for isolation).
- `--pr-tool`: PR-creation skill to dispatch to (e.g., `/quick-pr`, `/ado-pr`). Default: auto-detected from `git remote get-url origin` — GitHub → `/quick-pr`, Azure DevOps → `/ado-pr`. The mapping is extensible; new PR-creation skills can be added by extending the auto-detection table in this file.

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

  ## After coding
  - Push the branch: `git push -u origin <branch-name>`
  - Create a **draft** PR via `<pr-tool> --draft --target <target-branch>` (or the equivalent flag set for the chosen PR-creation skill).
  - Display a summary: branch name, number of commits, and PR URL.
  - Print a copiable command for the user to rename the session: `/rename PR #<number>: <title>` (use the PR number and title from the PR you just created). Note: `/rename` is a built-in CLI command that only the user can execute — Claude cannot run it programmatically.

  ---

  ```

  **Important:** All placeholders (`<branch-name>`, `<target-branch>`, `<pr-tool>`, `<sanitized-worktree-name>`) must be replaced with concrete values **before** writing to the plan file. The bracketed worktree-mode/no-worktree paragraph picks one and only one based on whether the user passed `--no-worktree`. The plan content follows after the `---` separator.

## Error Handling

- **No plan found**: Exit early with a clear message (see step 1).
- **Auto-detection of `--target` fails** (no `origin/HEAD`, no remote configured): fall back to `main` and print a notice. The user can override with `--target`.
- **Auto-detection of `--pr-tool` fails** (remote URL doesn't match any known host): ask the user which PR-creation skill to use rather than silently defaulting.
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
