# Notify Windows Hook

Windows toast notifications for runtime events, powered by [BurntToast](https://github.com/Windos/BurntToast).

Alerts when an agent needs attention, including permission prompts, questions, task completion, background agent completion, shell completion, and authentication events.

## Prerequisites

Install the BurntToast PowerShell module:

```powershell
Install-Module -Name BurntToast
```

## Install locations

- **Claude user-level** (all projects): `~\.claude\hooks\notify-windows\`
- **Claude project-level** (one project): `<project-root>\.claude\hooks\notify-windows\`
- **Copilot user-level** (all projects): `~\.copilot\hooks\notify-windows\`
- **Copilot project-level** (one project): `<project-root>\.github\hooks\notify-windows\`

## Installation

### Claude Code

Install script files:

```powershell
.\bin\terrarium-sync-claude-hooks.ps1
```

`claude.hooks.json` is the registration template. Copy its `"hooks"` block into `~\.claude\settings.json` or `<project-root>\.claude\settings.json`, then replace `{{CLAUDE_HOOK_DIR}}` with the full installed hook folder path, such as `~\.claude\hooks\notify-windows`.

Automatic hook registration is not implemented yet; #22 tracks safe registration/merge automation.

### Copilot CLI

Install script files and hook JSON:

```powershell
.\bin\terrarium-sync-copilot-hooks.ps1
```

The sync script copies `copilot.hooks.json` to `~\.copilot\hooks\notify-windows.json` and replaces `{{COPILOT_HOOK_DIR}}` with the installed hook folder path.

For Linux/macOS, POSIX Copilot sync parity is tracked by #21.

## Preset files

| Runtime | Preset file | Notes |
|---------|-------------|-------|
| Claude Code | `claude.hooks.json` | Manual registration template; replace `{{CLAUDE_HOOK_DIR}}`. |
| Copilot CLI | `copilot.hooks.json` | Installed by `terrarium-sync-copilot-hooks.ps1`; placeholder rewritten during sync. |

## Notification types

| Event | Title | Sound | Urgent | Expiry |
|-------|-------|-------|--------|--------|
| `permission_prompt` | Permission Required | Reminder | Yes | — |
| `elicitation_dialog` | Question for You | Reminder | Yes | — |
| `idle_prompt` | Task Complete | IM | No | 15 min |
| `auth_success` | Authentication | Silent | No | 5 min |
| `agent_completed` | Agent Complete | IM | No | 15 min |
| `agent_idle` | Agent Waiting | Reminder | Yes | — |
| `shell_completed` | Shell Complete | IM | No | 15 min |
| *(other)* | AI Agent | Default | No | 15 min |

## Customization

- **Logo** — Replace `claude-logo.png` with any image. The script resolves it relative to its own directory.
- **Sounds** — Change the `-Sound` parameter in `notify.ps1`. See BurntToast docs for available sounds.
- **Expiry** — Adjust the `-ExpirationTime` values to control how long notifications persist.
