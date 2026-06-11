# Settings

Reusable settings snippets and configuration guidance for supported runtimes.

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Available Settings

| Preset | Claude Code | Copilot CLI | Claude file | Copilot file | Description | Notes |
|--------|-------------|-------------|-------------|--------------|-------------|-------|
| Base | ✅ | ⚠️ | `settings\claude\base.json` | `settings\copilot\base.json` | General-purpose preferences and file/git shell permissions | Copilot JSON settings do not grant shell permissions; use launch flags or another permission mechanism. |
| ADO | ✅ | 🛠️ | `settings\claude\ado.json` | — | Azure DevOps CLI and MCP permissions | Copilot requires `/mcp` setup and permission-model translation tracked by #19. |
| GitHub | ✅ | ⚠️ | `settings\claude\github.json` | `settings\copilot\github.json` | GitHub CLI permissions and GitHub URL access | Copilot preset allows URLs only; `gh` shell permissions still need launch flags. |
| .NET | ✅ | 🛠️ | `settings\claude\dotnet.json` | — | C#/.NET shell permissions and Claude plugin setting | Copilot requires separate LSP/plugin or launch configuration; tracked by #19. |
| Work Status | ✅ | 🛠️ | `settings\claude\work-status.json` | — | MCP permissions for weekly status tracking | Copilot requires MCP setup plus path/tool permission translation tracked by #19. |

## Installation

Use sync scripts as the default installation path.

```powershell
.\bin\seiji-claude-sync-settings.ps1
.\bin\seiji-copilot-sync-settings.ps1
```

```sh
./bin/seiji-claude-sync-settings
# POSIX Copilot sync is tracked by #21.
```

## Claude Code settings

Claude presets live under `settings\claude\` and merge into `~\.claude\settings.json`.

```powershell
.\bin\seiji-claude-sync-settings.ps1 -DryRun
```

```sh
./bin/seiji-claude-sync-settings --dry-run
```

## Copilot CLI settings

Copilot JSON presets live under `settings\copilot\` and merge into `~\.copilot\settings.json`.

```powershell
.\bin\seiji-copilot-sync-settings.ps1 -DryRun
```

Copilot shell, MCP, URL, and path permissions are not represented by the same JSON schema as Claude Code `permissions.allow`. Use launch flags such as `--allow-tool`, `--deny-tool`, `--allow-url`, `/mcp` setup, skill `allowed-tools`, agent `tools`, or hooks instead of implying JSON parity.

Examples:

```powershell
copilot --allow-tool 'shell(git status)' --allow-tool 'shell(git diff)' --allow-tool 'shell(git log)'
copilot --allow-tool 'shell(gh pr view)' --allow-url 'https://github.com'
```

## Work Status preset path permissions

The work-status preset covers MCP tool permissions and reads `~\.agents\work-status-config.json`. Users should also add read/write permissions for their configured `statusRepoPath` directories when their runtime requires path allowlists.

```json
"Read(~/source/repos/work-status/weekly-statuses/**)",
"Read(~/source/repos/work-status/work-log/**)",
"Write(~/source/repos/work-status/weekly-statuses/**)",
"Write(~/source/repos/work-status/work-log/**)"
```
