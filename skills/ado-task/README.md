# Azure DevOps Task Management Skill

Create, update, complete, and list Azure DevOps work items from the command line.

## Prerequisites

- **Azure DevOps MCP server** — configured and running in your runtime
- **Configuration file** — `~\.agents\work-status-config.json`

```json
{
  "userEmail": "you@example.com",
  "adoProject": "Your Project",
  "adoTeam": "Your Team"
}
```

## Available Subcommands

| Subcommand | Description |
|------------|-------------|
| `create <title>` | Create a new work item (Task, Bug, or User Story) |
| `done <id> [notes]` | Close a work item with optional notes |
| `update <id> [--state] [notes]` | Change state and/or add a comment |
| `bulk <ids> [--state] [notes]` | Batch update multiple work items |
| `list [--all] [--filter] [--order-by]` | List assigned work items with filtering and sorting |

## Installation

Install user-level skill variants with the sync scripts.

- **Claude project-level** (one project): `<project-root>\.claude\skills\`
- **Claude user-level** (all projects): `~\.claude\skills\`
- **Copilot project-level** (one project): `<project-root>\.github\skills\`
- **Copilot user-level** (all projects): `~\.copilot\skills\`

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-sync-skills.ps1
.\bin\seiji-copilot-sync-skills.ps1
```

```sh
# Linux / macOS / POSIX
./bin/seiji-claude-sync-skills
# POSIX Copilot sync is tracked by #21.
```

### Permissions

For Claude Code, merge the ADO permissions preset into your settings file to auto-allow the MCP tools this skill uses:

```powershell
# Windows (PowerShell) — view the preset
Get-Content settings\claude\ado.json
```

See [settings\claude\ado.json](../../settings/claude/ado.json) for the full list of permitted MCP tools.

For Copilot CLI, configure the Azure DevOps MCP server with `/mcp` and approve or allow the equivalent ADO MCP tools exposed by that server.

## Usage Examples

```
/ado-task create Fix the auth token expiry bug --desc "Tokens expire silently" --type Bug   # Create a bug
/ado-task done 78901 Fixed by adding token refresh logic                             # Close one work item
/ado-task update 78901 --state Active Started working on this                       # Update state and add notes
/ado-task bulk 78901,78902 --state Closed "Closing old items"                       # Update several work items
/ado-task list                                                                      # List assigned work items
/ado-task list --filter "state=Active,New"                                          # Filter list results
/ado-task list --order-by "updated desc"                                            # Sort list results
```

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `userEmail` | No | — | Used for auto-assignment on `create` |
| `adoProject` | Yes | — | Azure DevOps project name |
| `adoTeam` | Yes | — | ADO team name (for sprint resolution) |
