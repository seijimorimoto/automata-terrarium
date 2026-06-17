# Azure DevOps PR Fix Skill

Fetches Azure DevOps PR review comments, investigates them, proposes actions, and, after approval, applies fixes, replies to reviewers, and resolves threads.

## Prerequisites

- **Git** — install from the [Git downloads page](https://git-scm.com/downloads):

  ```powershell
  # Windows (PowerShell)
  winget install --id Git.Git
  ```

  ```sh
  # Linux / macOS / POSIX
  brew install git
  # Debian / Ubuntu alternative:
  sudo apt-get update && sudo apt-get install -y git
  ```

- **Azure DevOps MCP server** — configured and running in your runtime.

  The server must expose Azure DevOps repo capabilities for repository lookup, pull request lookup/listing, pull request thread listing, thread comment listing, thread replies, and thread status updates. MCP server install commands vary by provider; use the command and server package from your Azure DevOps MCP provider.

  For Claude Code, register the server with your provider's command:

  ```powershell
  # Windows (PowerShell)
  claude mcp add ado -- <ado-mcp-server-command>
  ```

  ```sh
  # Linux / macOS / POSIX
  claude mcp add ado -- <ado-mcp-server-command>
  ```

  For Copilot CLI, start Copilot and configure the server through `/mcp`:

  ```powershell
  # Windows (PowerShell)
  copilot
  ```

  ```text
  /mcp
  ```

  Then merge the ADO permission preset described below when using Claude Code.

## Available Skills

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

| Skill | Claude Code | Copilot CLI | Description | Notes |
|-------|-------------|-------------|-------------|-------|
| `/ado-pr-fix` | ✅ | ✅ | Analyze and address Azure DevOps PR review comments with approval gates | Shared skill; requires Azure DevOps MCP PR thread tools. |

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

For project-level installs, the skills are available to anyone who clones the target project. Project-level sync support is not documented here yet.

## Permissions

For Claude Code, sync the settings presets after installing or updating this repository:

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-sync-settings.ps1
```

```sh
# Linux / macOS / POSIX
./bin/seiji-claude-sync-settings
```

This merges `settings\claude\ado.json` into `~\.claude\settings.json`. The ADO preset includes the Azure DevOps PR thread permissions used by this skill:

- `mcp__ado__repo_list_pull_request_thread_comments`
- `mcp__ado__repo_list_pull_request_threads`
- `mcp__ado__repo_reply_to_comment`
- `mcp__ado__repo_update_pull_request_thread`

For Copilot CLI, settings sync does not grant MCP permissions. Configure the Azure DevOps MCP server with `/mcp` and approve or allow the equivalent ADO MCP tools exposed by that server.

## Usage

```text
/ado-pr-fix
/ado-pr-fix 4942945
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `PR-NUMBER` | No | Active PR for the current branch | Numeric Azure DevOps pull request ID |

## Workflow

1. Resolve the Azure DevOps project, repository, and PR from the git remote and current branch or the provided PR number.
2. Fetch active PR review threads and filter out automated or non-actionable noise.
3. Investigate each actionable comment against the current codebase before proposing a change.
4. Classify each thread as `[Fix]`, `[Won't fix]`, or `[Needs discussion]`.
5. Pause for user approval before editing.
6. Apply approved fixes, show the diff, and pause again before committing and pushing.
7. Reply to acted-on threads and resolve them as `Fixed` or `WontFix`; leave discussion threads active.

## Safety gates

- The skill is read-only until the user approves proposed actions.
- It stages only intended files and does not use `git add -A` or `git add .`.
- It follows the target project's commit and branch instructions.
- It does not resolve `[Needs discussion]` threads unless the user explicitly approves a reply or status change.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No active PR is found | Pass the PR number explicitly: `/ado-pr-fix 12345`. |
| The git remote cannot be parsed | Confirm the repository remote is an Azure DevOps URL. |
| ADO MCP tools are unavailable | Configure the Azure DevOps MCP server, then restart or reconnect the runtime session. |
| Thread comments are missing | Confirm the MCP server exposes pull request thread comment listing. |
| Push fails | Resolve the git error manually or ask the agent to retry after fixing the reported issue. |
