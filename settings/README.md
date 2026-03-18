# Settings

Reusable Claude Code settings snippets and configurations.

## Available Settings

| Preset | File | Description |
|--------|------|-------------|
| Base | `base.json` | General-purpose permissions — file ops, git, grep |
| .NET | `dotnet.json` | C#/.NET permissions and the C# LSP plugin |
| Work Status | `work-status.json` | ADO + Todoist MCP permissions for work-status tracking skills |

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

## What goes here

- Permission presets (allowed/denied tool patterns)
- Model preferences
- Custom environment variables
- Any reusable `settings.json` fragments
