# Notify Hook

Windows toast notifications for Claude Code and Copilot CLI events, powered by [BurntToast](https://github.com/Windos/BurntToast).

Alerts you when an agent needs attention — permission prompts, questions, task completion, background agent completion, shell completion, and authentication events.

## Prerequisites

Install the BurntToast PowerShell module:

```powershell
Install-Module -Name BurntToast
```

## Installation

### 1. Copy to your runtime folder

Copy the `notify-windows` folder to a supported runtime location:

- **Claude user-level** (all projects): `~\.claude\hooks\`
- **Claude project-level** (one project): `<project-root>\.claude\hooks\`
- **Copilot user-level** (all projects): `~\.copilot\hooks\notify-windows\`
- **Copilot project-level** (one project): `<project-root>\.github\hooks\`

```powershell
Copy-Item -Recurse hooks\notify-windows ~\.claude\hooks\

# Copilot user-level script files
Copy-Item -Recurse hooks\notify-windows ~\.copilot\hooks\
```

### 2. Register in settings

Add the following to the matching `settings.json` (`~\.claude\settings.json` for user-level, or `<project-root>\.claude\settings.json` for project-level):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File hooks\\notify-windows\\notify.ps1"
          }
        ]
      }
    ]
  }
}
```

For Copilot CLI, install via the sync script:

```powershell
.\bin\seiji-copilot-sync-hooks.ps1
```

Or copy `hooks\notify-windows\copilot.hooks.json` to `~\.copilot\hooks\notify-windows.json` and replace `{{COPILOT_HOOK_DIR}}` with the full path to the installed `notify-windows` folder.

## Notification types

| Event               | Title               | Sound    | Urgent | Expiry   |
|---------------------|---------------------|----------|--------|----------|
| `permission_prompt` | Permission Required  | Reminder | Yes    | —        |
| `elicitation_dialog`| Question for You     | Reminder | Yes    | —        |
| `idle_prompt`       | Task Complete        | IM       | No     | 15 min   |
| `auth_success`      | Authentication       | Silent   | No     | 5 min    |
| `agent_completed`   | Agent Complete       | IM       | No     | 15 min   |
| `agent_idle`        | Agent Waiting        | Reminder | Yes    | —        |
| `shell_completed`   | Shell Complete       | IM       | No     | 15 min   |
| *(other)*           | AI Agent             | Default  | No     | 15 min   |

## Customization

- **Logo** — Replace `claude-logo.png` with any image. The script resolves it relative to its own directory.
- **Sounds** — Change the `-Sound` parameter in `notify.ps1`. See [BurntToast docs](https://github.com/Windos/BurntToast) for available sounds.
- **Expiry** — Adjust the `-ExpirationTime` values to control how long notifications persist.
