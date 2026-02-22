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

## Installation

Copy or symlink skill folders into your target project's `.claude/skills/` directory:

```bash
# Single skill
cp -r skills/my-skill <your-project>/.claude/skills/

# All skills
cp -r skills/*/ <your-project>/.claude/skills/
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
