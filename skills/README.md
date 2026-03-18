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

### Weekly Work Status Tracking

A suite of skills for tracking weekly work, generating status reports, managing ADO tasks, and preparing performance review narratives.

| Skill | Description |
|-------|-------------|
| [`/log`](log/) | Append a timestamped work entry to the current week's log file |
| [`/weekly-status`](weekly-status/) | Generate a weekly status report from ADO, Todoist, and local work log |
| [`/ado-task`](ado-task/) | Create, update, and manage Azure DevOps work items |
| [`/review-prep`](review-prep/) | Synthesize archived weekly statuses into impact-focused review narratives |

All four skills share a common config file (`~\.claude\work-status-config.json`). See the [weekly-status README](weekly-status/README.md) for full setup instructions.

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
