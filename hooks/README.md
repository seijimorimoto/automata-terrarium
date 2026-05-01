# Hooks

Event-driven scripts that run in response to Claude Code tool calls.

## Available Hooks

| Hook | Description | Platform |
|------|-------------|----------|
| [`notify-windows`](notify-windows/) | Windows toast notifications for Claude Code events (permission prompts, questions, task completion) | Windows |

> **Note:** Skill- and agent-scoped hooks live alongside their owning skill/agent under `skills/<name>/scripts/` or `agents/<name>/scripts/` and are registered via that skill's `SKILL.md` or that agent's `<name>.md` frontmatter — not via `settings.json`. They don't appear in this directory. Canonical examples: [`skills/ado-pr/`](../skills/ado-pr/) (a `PostToolUse` hook that captures PR output) and [`agents/verify-runner/`](../agents/verify-runner/) (a `PreToolUse` hook enforcing a read-only Bash allowlist). Only **session-wide hooks**, registered via `settings.json`, live here in `hooks/`.

## Installation

### 1. Copy hook files into your `.claude` folder

Hooks must live inside a `.claude` directory for Claude Code to find them. Copy the desired hook folder to either location:

- **User-level** (applies to all projects): `~\.claude\hooks\`
- **Project-level** (applies to one project): `<project-root>\.claude\hooks\`

For example, to install a hook called `my-hook` for all projects:

```powershell
# Windows (PowerShell)
Copy-Item -Recurse hooks\my-hook ~\.claude\hooks\
```

```sh
# Linux / macOS
cp -r hooks/my-hook ~/.claude/hooks/
```

### 2. Register the hook in settings

Add hook entries to the matching `settings.json` under the `"hooks"` key:

- **User-level**: `~\.claude\settings.json`
- **Project-level**: `<project-root>\.claude\settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": ["bash hooks/my-hook.sh"]
      }
    ]
  }
}
```

> **Note:** Hook paths in settings are relative to the `.claude` directory they live in.

## Hook Events Examples

| Event          | Fires when                        |
|----------------|-----------------------------------|
| `PreToolUse`   | Before a tool call executes       |
| `PostToolUse`  | After a tool call completes       |
| `Notification` | When Claude sends a notification  |

## Creating a New Hook

1. Create a script in this directory
2. The hook receives a JSON payload on stdin with tool name, input, and other context
3. Output JSON to stdout to modify behavior (e.g., block a tool call)
4. Make scripts executable (Linux/macOS): `chmod +x hooks/my-hook.sh`

See the [Claude Code docs](https://code.claude.com/docs/en/hooks) for more details.
