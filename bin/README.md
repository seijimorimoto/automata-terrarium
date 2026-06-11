# bin

Sync executables that install this repo's skills, agents, hooks, and settings into user-level runtime config directories.

Actual script renames are out of scope for this migration and tracked by #20. The tables below use conceptual `seiji-<orchestrator>-...` patterns while listing the current script files.

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Available Sync Scripts

| Conceptual script | Claude Code | Copilot CLI | Current files | Purpose | Notes |
|-------------------|-------------|-------------|---------------|---------|-------|
| `seiji-<orchestrator>-install` | ✅ | ❌ | `seiji-claude-install`, `seiji-claude-install.ps1` | One-time PATH setup for sync commands | Copilot install helper is not implemented; broader renames are tracked by #20. |
| `seiji-<orchestrator>-sync` | ✅ | ⚠️ | `seiji-claude-sync`, `seiji-claude-sync.ps1`, `seiji-copilot-sync.ps1` | Wrapper that runs skills, agents, hooks, then settings sync | Copilot wrapper is PowerShell-only; POSIX parity is tracked by #21. |
| `seiji-<orchestrator>-sync-skills` | ✅ | ⚠️ | `seiji-claude-sync-skills`, `seiji-claude-sync-skills.ps1`, `seiji-copilot-sync-skills.ps1` | Install compatible skill entrypoints | Copilot skill sync is PowerShell-only; POSIX parity is tracked by #21. |
| `seiji-<orchestrator>-sync-agents` | ✅ | ⚠️ | `seiji-claude-sync-agents`, `seiji-claude-sync-agents.ps1`, `seiji-copilot-sync-agents.ps1` | Install compatible agent/custom-agent profiles | Copilot agent sync is PowerShell-only; POSIX parity is tracked by #21. |
| `seiji-<orchestrator>-sync-hooks` | ✅ | ⚠️ | `seiji-claude-sync-hooks`, `seiji-claude-sync-hooks.ps1`, `seiji-copilot-sync-hooks.ps1` | Install hook script files and Copilot hook JSON | Hook registration/merge automation is tracked by #22; Copilot sync is PowerShell-only (#21). |
| `seiji-<orchestrator>-sync-settings` | ✅ | ⚠️ | `seiji-claude-sync-settings`, `seiji-claude-sync-settings.ps1`, `seiji-copilot-sync-settings.ps1` | Merge settings presets into user-level settings files | Claude reads `settings\claude\`; Copilot reads `settings\copilot\` and is PowerShell-only (#21). |

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
.\bin\seiji-claude-install.ps1
# Open a new PowerShell window so PATH refreshes.
seiji-claude-sync

.\bin\seiji-copilot-sync.ps1
```

```sh
# Linux / macOS / POSIX
./bin/seiji-claude-install
# Open a new shell so PATH refreshes.
seiji-claude-sync
# POSIX Copilot sync is tracked by #21.
```

## Per-category commands

```powershell
# Windows (PowerShell)
seiji-claude-sync-skills.ps1
seiji-claude-sync-agents.ps1
seiji-claude-sync-hooks.ps1
seiji-claude-sync-settings.ps1

.\bin\seiji-copilot-sync-skills.ps1
.\bin\seiji-copilot-sync-agents.ps1
.\bin\seiji-copilot-sync-hooks.ps1
.\bin\seiji-copilot-sync-settings.ps1
```

```sh
# Linux / macOS / POSIX
seiji-claude-sync-skills
seiji-claude-sync-agents
seiji-claude-sync-hooks
seiji-claude-sync-settings
# POSIX Copilot sync is tracked by #21.
```

## Settings merge rules

`seiji-claude-sync-settings` merges every `settings\claude\*.json` preset into `~\.claude\settings.json`. `seiji-copilot-sync-settings.ps1` merges every `settings\copilot\*.json` preset into `~\.copilot\settings.json`.

For each key:

- **Arrays of strings** such as `permissions.allow`, `permissions.deny`, and `permissions.ask` — union, dedupe, sort alphabetically.
- **Arrays of objects** such as hook entries — union, dedupe by deep JSON equality, preserve order.
- **Objects** — recursive merge.
- **Scalars** — preserve the user's existing value if set; otherwise write the preset value.

By default, settings sync scripts back up existing user settings before writing. Use `-NoBackup` or `--no-backup` to skip backup where supported, and `-DryRun` or `--dry-run` to preview without writing.

## What sync does not do

- It does not rename repo/bin scripts; #20 tracks that work.
- It does not provide POSIX Copilot sync scripts; #21 tracks that work.
- It does not auto-register or merge hook settings; #22 tracks that work.
- It does not translate Copilot's full permission model into JSON settings; #19 tracks that work.
