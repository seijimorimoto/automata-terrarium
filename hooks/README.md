# Hooks

Event-driven scripts that run in response to Claude Code tool calls.

## Available Hooks

| Hook | Description | Platform |
|------|-------------|----------|
| [`notify-windows`](notify-windows/) | Windows toast notifications for Claude Code events (permission prompts, questions, task completion) | Windows |

> **Note:** Agent-scoped PreToolUse hooks (e.g., `verify-runner-bash-guard`) live inside the agent's folder under `agents/<name>/` and are registered via the agent's frontmatter — not via `settings.json`. They do not appear in this directory. See [`agents/verify-runner/`](../agents/verify-runner/) for the canonical example.

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
