# Settings

Reusable settings snippets and configurations for Claude Code and GitHub Copilot CLI.

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Available Settings

| Preset | Claude Code | Copilot CLI | File | Description | Notes |
|--------|-------------|-------------|------|-------------|-------|
| Base | ✅ | ⚠️ | `base.json` | General-purpose permissions/preferences — file ops, git, grep | Claude preset includes `permissions.allow` entries. Copilot has only a minimal `settings\copilot\base.json`; shell permissions still need CLI flags such as `--allow-tool`. |
| ADO | ✅ | ⚠️ | `ado.json` | Azure DevOps MCP tool permissions — PRs, work items, iterations, repos | Claude MCP tool allowlist exists. Copilot requires `/mcp` setup and tool permissions through Copilot's MCP/tool permission model; no equivalent preset is complete yet. |
| GitHub | ✅ | ⚠️ | `github.json` | GitHub CLI (`gh`) permissions and GitHub URL access | Claude preset allows `gh` commands. Copilot preset currently allows GitHub URLs only; `gh` shell permissions still need `--allow-tool 'shell(gh ...)'` flags. |
| .NET | ✅ | ⚠️ | `dotnet.json` | C#/.NET permissions and the C# LSP plugin | Claude preset enables a Claude plugin and `dotnet` shell permission. Copilot should use `/lsp`, plugins, or CLI flags; no complete equivalent preset yet. |
| Work Status | ✅ | ⚠️ | `work-status.json` | MCP tool permissions for weekly status tracking (ADO + Todoist) | Claude MCP/path permissions exist. Copilot requires MCP setup plus path/tool permission flags and config path migration. |

## Installation

Each top-level preset is currently a Claude Code JSON fragment. Copilot equivalents live under `settings\copilot\` only where JSON config applies. A `⚠️` in the Copilot column means "partially represented, manual setup required, or planned" rather than parity with Claude's `permissions.allow` model.

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

Use `bin\seiji-copilot-sync-settings.ps1` to merge `settings\copilot\*.json` into `~\.copilot\settings.json`.

Copilot permission flags such as `--allow-tool`, `--deny-tool`, `--allow-url`, and `--allow-all-paths` are not represented by the same JSON schema as Claude Code `permissions.allow`. Use launch commands or helper scripts for those permissions rather than implying the JSON presets are equivalent.

Examples:

```powershell
# Allow read-only git inspection commands for one session
copilot --allow-tool 'shell(git status)' --allow-tool 'shell(git diff)' --allow-tool 'shell(git log)'

# Allow GitHub PR inspection and GitHub URL access
copilot --allow-tool 'shell(gh pr view)' --allow-url 'https://github.com'
```

When adding a Copilot preset, document whether it is:

- a real Copilot JSON setting,
- a launch flag recommendation,
- an MCP setup requirement,
- a skill `allowed-tools` / agent `tools` concern,
- or a hook configuration.

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
