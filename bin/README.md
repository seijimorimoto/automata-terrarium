# bin

Sync executables that install this repo's skills, agents, hooks, and settings into user-level runtime config directories.

The command namespace is `terrarium-*`.

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Available Sync Scripts

| Command family | Claude Code | Copilot CLI | Current files | Purpose | Notes |
|----------------|-------------|-------------|---------------|---------|-------|
| `terrarium-install` | ✅ | ✅ | `terrarium-install`, `terrarium-install.ps1` | One-time PATH setup for `terrarium-*` commands | Only performs PATH setup; no difference between runtimes. |
| `terrarium-sync-<runtime>` | ✅ | ⚠️ | `terrarium-sync-claude`, `terrarium-sync-claude.ps1`, `terrarium-sync-copilot.ps1` | Wrapper that runs skills, agents, hooks, then settings sync | Copilot wrapper is PowerShell-only; POSIX parity is tracked by #21. |
| `terrarium-sync-<runtime>-skills` | ✅ | ⚠️ | `terrarium-sync-claude-skills`, `terrarium-sync-claude-skills.ps1`, `terrarium-sync-copilot-skills.ps1` | Install compatible skill entrypoints | Copilot skill sync is PowerShell-only; POSIX parity is tracked by #21. |
| `terrarium-sync-<runtime>-agents` | ✅ | ⚠️ | `terrarium-sync-claude-agents`, `terrarium-sync-claude-agents.ps1`, `terrarium-sync-copilot-agents.ps1` | Install compatible agent/custom-agent profiles | Copilot agent sync is PowerShell-only; POSIX parity is tracked by #21. |
| `terrarium-sync-<runtime>-hooks` | ✅ | ⚠️ | `terrarium-sync-claude-hooks`, `terrarium-sync-claude-hooks.ps1`, `terrarium-sync-copilot-hooks.ps1` | Install hook script files and Copilot hook JSON | Hook registration/merge automation is tracked by #22; Copilot sync is PowerShell-only (#21). |
| `terrarium-sync-<runtime>-settings` | ✅ | ⚠️ | `terrarium-sync-claude-settings`, `terrarium-sync-claude-settings.ps1`, `terrarium-sync-copilot-settings.ps1` | Merge settings presets into user-level settings files | Claude reads `settings\claude\`; Copilot reads `settings\copilot\` and is PowerShell-only (#21). |

## Prerequisites

- **PowerShell 7+** (`pwsh`) — primary on Windows.
- **bash** with `readlink -f` — for Claude POSIX variants.
- **`jq` 1.6+** — required only by the Claude POSIX settings merge.

```powershell
# Windows (PowerShell)
winget install jqlang.jq
```

```sh
# Linux / macOS / POSIX
brew install jq
sudo apt-get install jq
```

## Quick start

```powershell
# Windows (PowerShell)
.\bin\terrarium-install.ps1
# Open a new PowerShell window so PATH refreshes.
terrarium-sync-claude

.\bin\terrarium-sync-copilot.ps1
```

```sh
# Linux / macOS / POSIX
./bin/terrarium-install
# Open a new shell so PATH refreshes.
terrarium-sync-claude
# POSIX Copilot sync is tracked by #21.
```

## Per-category commands

```powershell
# Windows (PowerShell)
terrarium-sync-claude-skills.ps1
terrarium-sync-claude-agents.ps1
terrarium-sync-claude-hooks.ps1
terrarium-sync-claude-settings.ps1

.\bin\terrarium-sync-copilot-skills.ps1
.\bin\terrarium-sync-copilot-agents.ps1
.\bin\terrarium-sync-copilot-hooks.ps1
.\bin\terrarium-sync-copilot-settings.ps1
```

```sh
# Linux / macOS / POSIX
terrarium-sync-claude-skills
terrarium-sync-claude-agents
terrarium-sync-claude-hooks
terrarium-sync-claude-settings
# POSIX Copilot sync is tracked by #21.
```

## Settings merge rules

`terrarium-sync-claude-settings` merges every `settings\claude\*.json` preset into `~\.claude\settings.json`. `terrarium-sync-copilot-settings.ps1` merges every `settings\copilot\*.json` preset into `~\.copilot\settings.json`.

For each key:

- **Arrays of strings** such as `permissions.allow`, `permissions.deny`, and `permissions.ask` — union, dedupe, sort alphabetically.
- **Arrays of objects** such as hook entries — union, dedupe by deep JSON equality, preserve order.
- **Objects** — recursive merge.
- **Scalars** — preserve the user's existing value if set; otherwise write the preset value.

By default, settings sync scripts back up existing user settings before writing. Use `-NoBackup` or `--no-backup` to skip backup where supported, and `-DryRun` or `--dry-run` to preview without writing.

## What sync does not do

- It does not provide POSIX Copilot sync scripts; #21 tracks that work.
- It does not auto-register or merge hook settings; #22 tracks that work.
- It does not translate Copilot's full permission model into JSON settings; #19 tracks that work.
