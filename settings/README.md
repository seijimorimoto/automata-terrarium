# Settings

Reusable Claude Code settings snippets and configurations.

## Available Settings

| Preset | File | Description |
|--------|------|-------------|
| Base | `base.json` | General-purpose permissions — file ops, git, grep |
| ADO | `ado.json` | Azure DevOps MCP tool permissions — PRs, work items, iterations, repos |
| GitHub | `github.json` | GitHub CLI (`gh`) permissions — PR creation, merging, and status |
| .NET | `dotnet.json` | C#/.NET permissions and the C# LSP plugin |
| Work Status | `work-status.json` | MCP tool permissions for weekly status tracking (ADO + Todoist) |
| verify-runner-bash-guard | `verify-runner-bash-guard.json` | Registers the [`verify-runner-bash-guard`](../hooks/verify-runner-bash-guard/) PreToolUse hook (Windows path) |

## Installation

Each preset is a JSON fragment. Copy the entries you need and merge them into your Claude Code settings file.

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
