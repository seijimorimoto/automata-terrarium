# Notify Hook

Windows toast notifications for Claude Code events, powered by [BurntToast](https://github.com/Windos/BurntToast).

Alerts you when Claude Code needs attention — permission prompts, questions, task completion, and authentication events.

## Prerequisites

Install the BurntToast PowerShell module:

```powershell
Install-Module -Name BurntToast
```

## Installation

### 1. Copy to your `.claude` folder

Copy the `notify` folder to either location:

- **User-level** (all projects): `~/.claude/hooks/`
- **Project-level** (one project): `<project-root>/.claude/hooks/`

```sh
cp -r hooks/notify ~/.claude/hooks/
```

### 2. Register in settings

Add the following to the matching `settings.json` (`~/.claude/settings.json` for user-level, or `<project-root>/.claude/settings.json` for project-level):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File hooks\\notify\\notify.ps1"
          }
        ]
      }
    ]
  }
}
```

## Notification types

| Event               | Title               | Sound    | Urgent | Expiry   |
|---------------------|---------------------|----------|--------|----------|
| `permission_prompt` | Permission Required  | Reminder | Yes    | —        |
| `elicitation_dialog`| Question for You     | Reminder | Yes    | —        |
| `idle_prompt`       | Task Complete        | IM       | No     | 15 min   |
| `auth_success`      | Authentication       | Silent   | No     | 5 min    |
| *(other)*           | Claude Code          | Default  | No     | 15 min   |

## Customization

- **Logo** — Replace `claude-logo.png` with any image. The script resolves it relative to its own directory.
- **Sounds** — Change the `-Sound` parameter in `notify.ps1`. See [BurntToast docs](https://github.com/Windos/BurntToast) for available sounds.
- **Expiry** — Adjust the `-ExpirationTime` values to control how long notifications persist.
