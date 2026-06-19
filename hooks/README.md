# Hooks

Event-driven scripts that run in response to runtime lifecycle events.

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Available Hooks

| Hook | Claude Code | Copilot CLI | Description | Platform | Notes |
|------|-------------|-------------|-------------|----------|-------|
| [`notify-windows`](notify-windows/) | ⚠️ | ⚠️ | Windows toast notifications for permission prompts, questions, completions, and shell events | Windows | Preset files exist for both runtimes; automatic registration/merge is tracked by #22. |

> **Note:** Skill- and agent-scoped hooks live alongside their owning skill/agent under `skills\<name>\scripts\` or `agents\<name>\scripts\` when that runtime supports scoped hook frontmatter. Copilot hooks are lifecycle/tool hooks registered through hook JSON or settings; they are not scoped by placing them in a skill or agent folder.

## Installation

Hook sync scripts copy hook script files. They do **not** automatically merge hook registrations into runtime settings yet; that registration/merge work is tracked by #22.

### Claude Code

Install script files:

```powershell
.\bin\terrarium-sync-claude-hooks.ps1
```

```sh
./bin/terrarium-sync-claude-hooks
```

Then use the checked-in preset `hooks\<name>\claude.hooks.json` as the registration template for `~\.claude\settings.json` or `<project-root>\.claude\settings.json`. Replace template placeholders such as `{{CLAUDE_HOOK_DIR}}` with the installed hook folder path.

### Copilot CLI

Install script files and Copilot hook JSON:

```powershell
.\bin\terrarium-sync-copilot-hooks.ps1
```

For Linux/macOS, POSIX Copilot sync parity is tracked by #21.

Copilot hook presets live at `hooks\<name>\copilot.hooks.json` and sync to `~\.copilot\hooks\<name>.json`.

## Hook Events Examples

| Event | Fires when |
|-------|------------|
| `PreToolUse` | Before a tool call executes |
| `PostToolUse` | After a tool call completes |
| `Notification` | When the runtime sends a notification |

## Creating a New Hook

1. Create a folder under `hooks\` with the hook script and a README.
2. Add runtime preset files using `<orchestrator>.hooks.json`, such as `claude.hooks.json` or `copilot.hooks.json`.
3. Document install locations, prerequisites, and registration steps in the hook README.
4. Update the Available Hooks tables in this README and the repo-level README.
