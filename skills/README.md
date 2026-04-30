# Skills

Custom slash-command skills for Claude Code.

## Available Skills

### Azure DevOps PR Integration

A suite of skills that bring GitHub-like PR session linking to Azure DevOps.

| Skill | Description |
|-------|-------------|
| [`/ado-pr`](ado-pr/) | Create a pull request in Azure DevOps with standardized formatting |
| [`/ado-resume-pr`](ado-resume-pr/) | Resume the Claude session that created a specific PR |
| [`/ado-pr-status`](ado-pr-status/) | List all tracked PRs (current repo or all repos) |

See the [ADO PR Integration README](ado-pr/README.md) for full documentation, installation, and troubleshooting.

### Azure DevOps Work Item Management

| Skill | Description |
|-------|-------------|
| [`/ado-task`](ado-task/) | Create, update, complete, and list Azure DevOps work items |

See the [ADO Task README](ado-task/README.md) for full documentation, installation, and configuration.

### Weekly Work Status Tracking

Skills for logging work, generating status reports, and preparing performance review materials. Data is stored in a configurable directory (default: `~\.claude\work-status\`). See [Configuration](weekly-status/README.md#prerequisites) for setup.

| Skill | Description |
|-------|-------------|
| [`/log`](log/) | Append a timestamped work entry to the current week's log |
| [`/weekly-status`](weekly-status/) | Generate a weekly status report from ADO, Todoist, and local log |

### GitHub Quick PR

| Skill | Description |
|-------|-------------|
| [`/quick-pr`](quick-pr/) | Create a branch, commit, push, open a GitHub PR, squash-merge, and clean up |

See the [Quick PR README](quick-pr/README.md) for full documentation, installation, and usage.

### Git Worktree Cleanup

| Skill | Description |
|-------|-------------|
| [`/cleanup-worktree`](cleanup-worktree/) | Remove a git worktree and its associated local branch after PR merge |

See the [Cleanup Worktree README](cleanup-worktree/README.md) for full documentation.

### Coverage Check

| Skill | Description |
|-------|-------------|
| [`/coverage-check`](coverage-check/) | Detect the project's coverage tool, run coverage scoped to the diff, classify each uncovered chunk by kind (`pure_logic` / `trivial` / `untestable` / `generated`); emits JSON findings |

See the [Coverage Check README](coverage-check/README.md) for the supported toolchains, threshold resolution, output schema, and chunk-kind heuristics.

### Documentation Review

| Skill | Description |
|-------|-------------|
| [`/doc-review`](doc-review/) | Inspect the diff for missing/stale documentation and emit report-only JSON findings (doc accuracy, stale references, missing doc-comments, suggest-new-docs, index linkage) |

See the [Doc Review README](doc-review/README.md) for what it checks, the per-language doc-comment recognizers, and the output schema.

### Standards Verification

| Skill | Description |
|-------|-------------|
| [`/standards-check`](standards-check/) | Discover a repo's standards files, extract rules, check the diff against them; emits tiered JSON findings (`hard_block` / `soft_block` / `report`) |

See the [Standards Check README](standards-check/README.md) for prereqs, output schema, the diff-scoped discovery model, and how to extend the pre-baked recognizers.

### Plan Implementation

| Skill | Description |
|-------|-------------|
| [`/implement`](implement/) | Carry out an approved plan: branch (or worktree), per-step commits, draft PR via the right PR-creation skill |

See the [Implement Plan README](implement/README.md) for prereqs, the parameter table, the workflow, and how to register a new PR-creation skill in the auto-detection table.

## Installation

Skills must live inside a `.claude\skills\` directory for Claude Code to find them. Copy or symlink skill folders to either location:

- **Project-level** (one project): `<project-root>\.claude\skills\`
- **User-level** (all projects): `~\.claude\skills\`

```powershell
# Windows (PowerShell)

# Single skill (project-level)
Copy-Item -Recurse skills\my-skill <your-project>\.claude\skills\

# All skills (user-level)
Copy-Item -Recurse skills\* ~\.claude\skills\
```

```sh
# Linux / macOS

# Single skill (project-level)
cp -r skills/my-skill <your-project>/.claude/skills/

# All skills (user-level)
cp -r skills/*/ ~/.claude/skills/
```

## Creating a New Skill

1. Create a new directory under `skills/` named after your skill
2. Add a `SKILL.md` file inside it with the prompt/instructions
3. Use `$ARGUMENTS` placeholder for user-provided arguments
4. Add a `README.md` for human-readable documentation of the skill if needed
5. Document any prerequisites (CLI tools, authentication, OS requirements) in the skill's `README.md`

See the [Claude Code docs](https://code.claude.com/docs/en/skills) for more details.

### Skill-Scoped Hooks

Hooks can be attached to individual skills via YAML frontmatter in the `SKILL.md`:

```yaml
---
name: my-skill
hooks:
  PostToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: powershell.exe -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -Command "$input | & \"$env:CLAUDE_PROJECT_DIR\.claude\skills\my-skill\scripts\my-hook.ps1\""
---
```

This is more efficient than global hooks since they only run when the skill executes.

> **Note:** On Windows, use PowerShell scripts (`.ps1`) for hooks. The `$env:CLAUDE_PROJECT_DIR` environment variable provides the project root path. Invoke PowerShell with `-Command` (not `-File`), as `-File` does not resolve `$env:CLAUDE_PROJECT_DIR` properly.
