# Azure DevOps Task Management Skill

Create, update, complete, and list Azure DevOps work items from the command line.

## Prerequisites

- **Azure DevOps MCP server** — configured and running in your Claude Code environment
- **Configuration file** — `~\.claude\work-status-config.json` with your ADO project details

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

Copy the skill folder to either location:

- **Project-level** (one project): `<project-root>\.claude\skills\`
- **User-level** (all projects): `~\.claude\skills\`

```powershell
# Windows (PowerShell)

# Project-level
Copy-Item -Recurse skills\ado-task <your-project>\.claude\skills\

# User-level
Copy-Item -Recurse skills\ado-task ~\.claude\skills\
```

```sh
# Linux / macOS

# Project-level
cp -r skills/ado-task <your-project>/.claude/skills/

# User-level
cp -r skills/ado-task ~/.claude/skills/
```

### Permissions

Merge the ADO permissions preset into your settings file to auto-allow the MCP tools this skill uses:

```powershell
# Windows (PowerShell) — view the preset
Get-Content settings\ado.json
```

See [settings\ado.json](../../settings/ado.json) for the full list of permitted MCP tools.

## Usage Examples

```
/ado-task create Fix the auth token expiry bug --desc "Tokens expire silently" --type Bug
/ado-task done 78901 Fixed by adding token refresh logic
/ado-task update 78901 --state Active Started working on this
/ado-task bulk 78901,78902 --state Closed "Closing old items"
/ado-task list
/ado-task list --filter "state=Active,New"
/ado-task list --order-by "updated desc"
```

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `userEmail` | No | — | Used for auto-assignment on `create` |
| `adoProject` | Yes | — | Azure DevOps project name |
| `adoTeam` | Yes | — | ADO team name (for sprint resolution) |
