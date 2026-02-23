# Hooks

Event-driven scripts that run in response to Claude Code tool calls.

## Installation

### 1. Copy hook files into your `.claude` folder

Hooks must live inside a `.claude` directory for Claude Code to find them. Copy the desired hook folder to either location:

- **User-level** (applies to all projects): `~/.claude/hooks/`
- **Project-level** (applies to one project): `<project-root>/.claude/hooks/`

For example, to install the `notify` hook for all projects:

```sh
cp -r hooks/notify ~/.claude/hooks/
```

### 2. Register the hook in settings

Add hook entries to the matching `settings.json` under the `"hooks"` key:

- **User-level**: `~/.claude/settings.json`
- **Project-level**: `<project-root>/.claude/settings.json`

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

## Hook events examples

| Event          | Fires when                        |
|----------------|-----------------------------------|
| `PreToolUse`   | Before a tool call executes       |
| `PostToolUse`  | After a tool call completes       |
| `Notification` | When Claude sends a notification  |

## Creating a new hook

1. Create a script in this directory
2. The hook receives a JSON payload on stdin with tool name, input, and other context
3. Output JSON to stdout to modify behavior (e.g., block a tool call)
4. Make scripts executable: `chmod +x hooks/my-hook.sh`

See the [Claude Code docs](https://code.claude.com/docs/en/hooks) for more details.
