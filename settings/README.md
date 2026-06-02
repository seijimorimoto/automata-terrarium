# Settings

Reusable settings snippets and configurations for Claude Code and GitHub Copilot CLI.

Support markers: `✅` supported, `❌` not supported, `⚠️` partial/manual/planned.

## Available Settings

| Preset | Claude Code | Copilot CLI | File | Description |
|--------|-------------|-------------|------|-------------|
| Base | ✅ | ⚠️ | `base.json` | General-purpose permissions — file ops, git, grep |
| ADO | ✅ | ⚠️ | `ado.json` | Azure DevOps MCP tool permissions — PRs, work items, iterations, repos |
| GitHub | ✅ | ⚠️ | `github.json` | GitHub CLI (`gh`) permissions — PR creation, merging, and status |
| .NET | ✅ | ⚠️ | `dotnet.json` | C#/.NET permissions and the C# LSP plugin |
| Work Status | ✅ | ⚠️ | `work-status.json` | MCP tool permissions for weekly status tracking (ADO + Todoist) |

## Installation

Each current preset is a Claude Code JSON fragment. Copilot equivalents are planned under `settings\copilot\` because Copilot permissions use different surfaces: CLI flags, `~\.copilot\settings.json`, `allowedUrls`, `deniedUrls`, `trustedFolders`, custom agent `tools`, skill `allowed-tools`, MCP config, and hooks.

### User-level (applies to all projects)

```powershell
# Windows (PowerShell) — open the user-level settings file
code ~\.claude\settings.json
```

```sh
# Linux / macOS — open the user-level settings file
code ~/.claude/settings.json
```

### Project-level (applies to a single project)

```powershell
# Windows (PowerShell) — open the project-level settings file
code <project-root>\.claude\settings.json
```

```sh
# Linux / macOS — open the project-level settings file
code <project-root>/.claude/settings.json
```

Then manually merge the chosen entries from the desired preset into your settings file.

### Copilot settings

Copilot user-level settings live in `~\.copilot\settings.json`. Project-level settings can live in `<project-root>\.github\copilot\settings.json` or `<project-root>\.github\copilot\settings.local.json`.

Copilot permission flags such as `--allow-tool`, `--deny-tool`, `--allow-url`, and `--allow-all-paths` may need launch helpers rather than JSON fragments. Planned Copilot presets should document the exact command or config surface they use.

### Work Status preset — additional path permissions

The `work-status.json` preset covers MCP tool permissions, but users should also add **Read/Write permissions** for their `statusRepoPath` directories to avoid permission prompts. For example, if `statusRepoPath` is `~/source/repos/work-status/`:

```json
"Read(~/source/repos/work-status/weekly-statuses/**)",
"Read(~/source/repos/work-status/work-log/**)",
"Write(~/source/repos/work-status/weekly-statuses/**)",
"Write(~/source/repos/work-status/work-log/**)"
```

Add these entries to the `permissions.allow` array in your settings file, adjusting the path to match your configured `statusRepoPath`.

## What goes here

- Permission presets (allowed/denied tool patterns)
- Model preferences
- Custom environment variables
- Any reusable `settings.json` fragments
- Copilot launch helpers or permission notes when a JSON fragment is not the right representation
