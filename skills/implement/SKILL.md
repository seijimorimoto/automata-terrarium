---
name: implement
description: Implement a plan from the current session — creates a branch, codes with auto-edits, commits each step, and opens a draft PR
argument-hint: "[--branch NAME] [--target BRANCH] [--no-worktree]"
---

# Implement Plan

Implements a plan that was created earlier in the current Claude Code session. Enters "Edit automatically" mode, creates a feature branch, makes logical commits at each step, and finishes by opening a draft PR via `/ado-pr`.

## Usage

```
/implement [--branch NAME] [--target BRANCH] [--no-worktree]
```

## Parameters

- `--branch`: Branch name to create (default: auto-generated from the plan summary, following any branch naming convention defined in the project's CLAUDE.md; if none is defined, uses `{alias}/{short-kebab-case-feature-title}`)
- `--target`: Target branch for the eventual PR (default: master)
- `--no-worktree`: Skip worktree creation and work directly in the current working tree (default behavior is to use a git worktree for isolation)

## Instructions

When this skill is invoked:

1. **Find the plan.** Look back through the current conversation for a plan that was presented to the user (e.g., via plan mode, a numbered step list, or an explicit implementation plan). If **no plan is found**, inform the user:
   > "No implementation plan found in this session. Please create a plan first (e.g., using /plan or by asking me to plan the implementation), then invoke /implement."

2. **Prepare the plan file.** Read the plan file used by plan mode to check its current contents.
   - If the plan file already contains the plan, **prepend** the implementation workflow instructions (see below) to the existing plan content.
   - If the plan file does not contain the plan (e.g., the plan was discussed conversationally rather than through plan mode), write **both** the implementation workflow instructions and the complete plan (all steps, context, file paths, and relevant details) to the plan file.

3. **Start a fresh context.** Use **ExitPlanMode** to transition into a fresh context window for implementation — just like the native plan mode flow.

  The implementation workflow instructions to prepend/include in the plan file are:

  ```
  # Implementation Workflow

  Follow these steps to implement the plan below. Edit files automatically without asking for confirmation on each change — the user has opted in.

  ## Before coding
  - Follow the branch naming convention in the project's CLAUDE.md if one exists; otherwise use `{alias}/{short-kebab-case-feature-title}` where `{alias}` is the part before `@` from `git config user.email`.
  {if --branch was provided: "- Use this branch name: `<branch-name>`"}
  {if --no-worktree was NOT provided (default behavior):
    - **Create a worktree** for isolated development using the **EnterWorktree** tool.
    - Derive the worktree name from the branch name by replacing any `/` characters with `-` (e.g., branch `u/alias/my-feature` → worktree name `u-alias-my-feature`).
    - Call `EnterWorktree` with that sanitized name.
    - After entering the worktree, **rename the auto-created branch** to match the desired branch name: `git branch -m <branch-name>`.
    - All subsequent work (coding, commits, push, PR) happens inside this worktree.
  }
  {if --no-worktree was provided:
    - Create a new git branch for this work.
  }
  {if --target was provided:
    - Target branch for PR: `<target-branch>`
  }
  {else:
    - Target branch for PR: `master`
  }

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
  - If the branch has merge conflicts with the target, **stop and inform the user** — do not force-push or auto-resolve.

  ## After coding
  - Push the branch: `git push -u origin <branch-name>`
  - Create a **draft** PR using `/ado-pr --draft --target <target-branch>`.
  - Display a summary: branch name, number of commits, and PR URL.
  - Print a copiable command for the user to rename the session: `/rename PR #<number>: <title>` (use the PR number and title from the PR you just created). Note: `/rename` is a built-in CLI command that only the user can execute — Claude cannot run it programmatically.

  ---

  ```

  **Important:** Replace `{if ...}` placeholders above with the actual resolved values (or omit them) based on the arguments the user passed to `/implement`. The plan content should follow after the `---` separator.

## Error Handling

- **No plan found**: Exit early with a clear message (see step 1).
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

Both:
```
/implement --branch johndoe/add-digest-email --target develop
```

Implement without worktree isolation (work directly in the current tree):
```
/implement --no-worktree
```
