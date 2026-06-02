# Hooks

Event-driven scripts that run in response to Claude Code or GitHub Copilot CLI lifecycle events.

Support markers: `✅` supported, `❌` not supported, `⚠️` partial/manual/planned.

## Available Hooks

| Hook | Claude Code | Copilot CLI | Description | Platform |
|------|-------------|-------------|-------------|----------|
| [`notify-windows`](notify-windows/) | ✅ | ✅ | Windows toast notifications for agent events (permission prompts, questions, task completion) | Windows |

> **Note:** Claude skill- and agent-scoped hooks live alongside their owning skill/agent under `skills\<name>\scripts\` or `agents\<name>\scripts\` and are registered via that skill's `SKILL.md` or that agent's `<name>.md` frontmatter — not via `settings.json`. Copilot hooks use JSON hook configuration under `~\.copilot\hooks\`, `<project-root>\.github\hooks\`, or Copilot settings. Canonical Claude examples: [`skills\ado-pr\`](../skills/ado-pr/) and [`agents\verify-runner\`](../agents/verify-runner/).

## Installation

### 1. Copy hook files into your runtime folder

Claude hooks must live inside a `.claude` directory. Copilot hook JSON can live under `~\.copilot\hooks\` or `<project-root>\.github\hooks\`.

- **Claude user-level** (applies to all projects): `~\.claude\hooks\`
- **Claude project-level** (applies to one project): `<project-root>\.claude\hooks\`
- **Copilot user-level** (applies to all projects): `~\.copilot\hooks\`
- **Copilot project-level** (applies to one project): `<project-root>\.github\hooks\`

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

Copilot hook entries use Copilot's JSON hook schema. Prefer a checked-in template such as `hooks\<name>\copilot.hooks.json` and install it to `~\.copilot\hooks\<name>.json` or `<project-root>\.github\hooks\<name>.json`.

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
