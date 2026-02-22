# Hooks

Event-driven scripts that run in response to Claude Code tool calls.

## Installation

Add hook entries to `~/.claude/settings.json` under the `"hooks"` key:

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
