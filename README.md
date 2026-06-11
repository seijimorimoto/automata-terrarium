# Seiji-Claude

Reusable AI agent workflows for Claude Code and GitHub Copilot CLI: skills, agents, hooks, settings, and sync scripts.

`AGENTS.md` is the canonical project instruction file. `CLAUDE.md` remains as a compatibility symlink for Claude Code.

## Support markers

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Setup

After cloning, install the git pre-commit hook to enforce the PR-only workflow:

```powershell
# Windows (PowerShell)
Copy-Item git-hooks\pre-commit .git\hooks\pre-commit
```

```sh
# Linux / macOS / POSIX
cp git-hooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Local skill testing

The repo includes `.claude\skills` and `.github\skills` symlinks pointing to `skills\` so Claude Code and Copilot CLI can discover skills directly from the repo for project-level testing.

On Windows, symlinks may require Developer Mode or an elevated terminal.

## Structure

```text
agents\    - Agent/custom-agent source variants
bin\       - Sync executables that install artifacts to user-level config
hooks\     - Event-driven hook scripts and runtime hook presets
settings\  - Runtime settings snippets and permission/config presets
skills\    - AI agent skills; shared or target-specific entrypoints
```

## Quick reference

| Type | Claude Code install location | Copilot CLI install location | Docs | Notes |
|------|------------------------------|-------------------------------|------|-------|
| Agents | `~\.claude\agents\` or `<project>\.claude\agents\` | `~\.copilot\agents\` or `<project>\.github\agents\` | [agents\README.md](agents/README.md) |  |
| Bin / sync scripts | `bin\seiji-claude-*` | `bin\seiji-copilot-*` | [bin\README.md](bin/README.md) | Copilot POSIX parity is tracked by #21. |
| Hooks | `~\.claude\hooks\` or `<project>\.claude\hooks\` | `~\.copilot\hooks\` or `<project>\.github\hooks\` | [hooks\README.md](hooks/README.md) | Registration merge automation is tracked by #22. |
| Settings | `~\.claude\settings.json` or `<project>\.claude\settings.json` | `~\.copilot\settings.json` or `<project>\.github\copilot\settings.json` | [settings\README.md](settings/README.md) | Copilot permissions are not equivalent to Claude `permissions.allow`; see #19. |
| Skills | `~\.claude\skills\` or `<project>\.claude\skills\` | `~\.copilot\skills\` or `<project>\.github\skills\` | [skills\README.md](skills/README.md) |  |

<details>
<summary><strong>Available Agents</strong></summary>

| Agent | Claude Code | Copilot CLI | Description | Tools | Docs | Notes |
|-------|-------------|-------------|-------------|-------|------|-------|
| `verify-runner` | ✅ | ⚠️ | Read-only verification agent that runs one check against the diff and returns JSON findings | Claude: `Skill, Read, Grep, Glob, Bash`; Copilot: `read, search, execute` | [agents\verify-runner](agents/verify-runner/) | Copilot lacks the Claude-style agent-frontmatter-scoped Bash guard. |

</details>

<details>
<summary><strong>Available Sync Scripts</strong></summary>

| Conceptual script | Claude Code | Copilot CLI | Current files | Purpose | Notes |
|-------------------|-------------|-------------|---------------|---------|-------|
| `seiji-<orchestrator>-install` | ✅ | ❌ | `seiji-claude-install`, `seiji-claude-install.ps1` | One-time PATH setup for sync commands | Copilot install helper is not implemented; broader renames are tracked by #20. |
| `seiji-<orchestrator>-sync` | ✅ | ⚠️ | `seiji-claude-sync`, `seiji-claude-sync.ps1`, `seiji-copilot-sync.ps1` | Wrapper that runs skills, agents, hooks, then settings sync | Copilot wrapper is PowerShell-only; POSIX parity is tracked by #21. |
| `seiji-<orchestrator>-sync-skills` | ✅ | ⚠️ | `seiji-claude-sync-skills`, `seiji-claude-sync-skills.ps1`, `seiji-copilot-sync-skills.ps1` | Install compatible skill entrypoints | Copilot skill sync is PowerShell-only; POSIX parity is tracked by #21. |
| `seiji-<orchestrator>-sync-agents` | ✅ | ⚠️ | `seiji-claude-sync-agents`, `seiji-claude-sync-agents.ps1`, `seiji-copilot-sync-agents.ps1` | Install compatible agent/custom-agent profiles | Copilot agent sync is PowerShell-only; POSIX parity is tracked by #21. |
| `seiji-<orchestrator>-sync-hooks` | ✅ | ⚠️ | `seiji-claude-sync-hooks`, `seiji-claude-sync-hooks.ps1`, `seiji-copilot-sync-hooks.ps1` | Install hook script files and Copilot hook JSON | Hook registration/merge automation is tracked by #22; Copilot sync is PowerShell-only (#21). |
| `seiji-<orchestrator>-sync-settings` | ✅ | ⚠️ | `seiji-claude-sync-settings`, `seiji-claude-sync-settings.ps1`, `seiji-copilot-sync-settings.ps1` | Merge settings presets into user-level settings files | Claude reads `settings\claude\`; Copilot reads `settings\copilot\` and is PowerShell-only (#21). |

</details>

<details>
<summary><strong>Available Hooks</strong></summary>

| Hook | Claude Code | Copilot CLI | Description | Platform | Docs | Notes |
|------|-------------|-------------|-------------|----------|------|-------|
| `notify-windows` | ⚠️ | ⚠️ | Windows toast notifications for agent events | Windows | [README](hooks/notify-windows/README.md) | Preset files exist for both runtimes; automatic registration/merge is tracked by #22. |

</details>

<details>
<summary><strong>Available Settings</strong></summary>

| Preset | Claude Code | Copilot CLI | Claude file | Copilot file | Description | Notes |
|--------|-------------|-------------|-------------|--------------|-------------|-------|
| ADO | ✅ | 🛠️ | `settings\claude\ado.json` | — | Azure DevOps CLI and MCP permissions | Copilot requires `/mcp` setup and permission-model translation tracked by #19. |
| Base | ✅ | ⚠️ | `settings\claude\base.json` | `settings\copilot\base.json` | General-purpose preferences and file/git shell permissions | Copilot JSON settings do not grant shell permissions; use launch flags or another permission mechanism. |
| .NET | ✅ | 🛠️ | `settings\claude\dotnet.json` | — | C#/.NET shell permissions and Claude plugin setting | Copilot requires separate LSP/plugin or launch configuration; tracked by #19. |
| GitHub | ✅ | ⚠️ | `settings\claude\github.json` | `settings\copilot\github.json` | GitHub CLI permissions and GitHub URL access | Copilot preset allows URLs only; `gh` shell permissions still need launch flags. |
| Work Status | ✅ | 🛠️ | `settings\claude\work-status.json` | — | MCP permissions for weekly status tracking | Copilot requires MCP setup plus path/tool permission translation tracked by #19. |

</details>

<details>
<summary><strong>Available Skills</strong></summary>

| Skill | Claude Code | Copilot CLI | Description | Docs | Notes |
|-------|-------------|-------------|-------------|------|-------|
| `/ado-pr` | ✅ | ✅ | Create Azure DevOps PRs with standardized formatting | [README](skills/ado-pr/README.md) | Shared skill. |
| `/ado-task` | ✅ | ✅ | Create, update, complete, and list Azure DevOps work items | [README](skills/ado-task/README.md) | Requires Azure DevOps MCP setup. |
| `/cleanup-worktree` | ✅ | ✅ | Remove a git worktree and its local branch after PR merge | [README](skills/cleanup-worktree/README.md) | Uses local git commands only. |
| `/coverage-check` | ✅ | ✅ | Run diff coverage, classify uncovered chunks, and emit JSON findings | [README](skills/coverage-check/README.md) | Requires a project coverage tool when coverage is expected. |
| `/doc-review` | ✅ | ✅ | Inspect the diff for missing or stale documentation and emit report-only findings | [README](skills/doc-review/README.md) | Uses local git diff context. |
| `/implement` | ✅ | ✅ | Implement a plan from a session, file, issue, PR, work item, or readable reference | [README](skills/implement/README.md) | Defaults to repo checks; native or equivalent checks are best-effort. |
| `/log` | ✅ | ✅ | Append timestamped work entries to the current week's log | [SKILL.md](skills/log/SKILL.md) | Uses agent-neutral `~\.agents\` work-status paths. |
| `/quick-pr` | ✅ | ✅ | Create a branch, commit, push, open a GitHub PR, optionally merge, and clean up | [README](skills/quick-pr/README.md) | Requires GitHub CLI authentication. |
| `/standards-check` | ✅ | ✅ | Discover project instructions and standards files, check the diff, and emit tiered JSON findings | [README](skills/standards-check/README.md) | Uses local git and helper scripts. |
| `/weekly-status` | ✅ | ✅ | Generate weekly status from Azure DevOps, Todoist, and local work logs | [README](skills/weekly-status/README.md) | Requires ADO/Todoist MCP setup. |

</details>

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

## Validation

```powershell
# Windows (PowerShell)
.\bin\seiji-validate.ps1
```
