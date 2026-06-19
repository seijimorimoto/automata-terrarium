# Claude settings

Claude Code settings fragments merge into `~\.claude\settings.json` with `bin\terrarium-sync-claude-settings.ps1`.

## Available presets

| Preset | File | Purpose |
|--------|------|---------|
| ADO | `ado.json` | Azure DevOps CLI and MCP permissions |
| Base | `base.json` | General file, git, and shell permissions |
| .NET | `dotnet.json` | C#/.NET shell permissions and Claude plugin setting |
| GitHub | `github.json` | GitHub CLI permissions |
| Work Status | `work-status.json` | Weekly-status MCP permissions and config-file read access |

## Install

```powershell
# Windows (PowerShell)
.\bin\terrarium-sync-claude-settings.ps1
.\bin\terrarium-sync-claude-settings.ps1 -DryRun
```

```sh
# Linux / macOS / POSIX
./bin/terrarium-sync-claude-settings
./bin/terrarium-sync-claude-settings --dry-run
```
