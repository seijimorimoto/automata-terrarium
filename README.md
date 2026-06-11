# Seiji-Claude

A collection of reusable AI agent workflows for Claude Code and GitHub Copilot CLI: skills, agents, hooks, settings, and sync scripts.

## AI orchestrator support

This repo is transitioning from Claude Code-only artifacts to dual Claude Code and GitHub Copilot CLI support. `AGENTS.md` is the canonical instruction file; `CLAUDE.md` remains as a compatibility symlink for Claude Code.

Support tables use:

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
# Linux / macOS
cp git-hooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

This prevents direct commits to `main` — all changes must go through feature branches and pull requests.

### Local skill testing

The repo includes a `.claude\skills` symlink pointing to the `skills\` directory. This lets Claude Code discover and run skills directly from the repo without copying them to your user-level `~\.claude\skills\` directory.

> **Note:** On Windows, symlinks may require Developer Mode enabled or an elevated terminal. If the symlink doesn't work after cloning, recreate it manually:

```powershell
# Windows (PowerShell — run as admin or with Developer Mode enabled)
New-Item -ItemType SymbolicLink -Path .claude\skills -Target (Resolve-Path skills)

# Or using mklink (Command Prompt — run as admin)
mklink /D .claude\skills skills
```

```sh
# Linux / macOS
ln -sf "$(pwd)/skills" .claude/skills
```

## Structure

```
skills/    - AI agent skills; shared or target-specific entrypoints
agents/    - Claude subagents and Copilot custom agent profiles
hooks/     - Event-driven hook scripts and runtime-specific hook registrations
settings/  - Reusable settings snippets and permission/config presets
bin/       - Sync executables that install artifacts to ~\.claude\ or ~\.copilot\
```

## Usage

Each directory contains its own README with setup instructions. To use any item, copy or symlink it into your target project's `.claude/skills/` directory.

### Quick reference

> **Paths:** Shown in Windows format (`\`). On Linux/macOS, use forward slashes (`/`) instead.

| Type     | Claude Code install location                           | Copilot CLI install location                         | Docs                          | Notes |
|----------|--------------------------------------------------------|-------------------------------------------------------|-------------------------------|-------|
| Skills   | `~\.claude\skills\` or `<project>\.claude\skills\`     | `~\.copilot\skills\` or `<project>\.github\skills\`  | [skills/README.md](skills/)   |  |
| Agents   | `~\.claude\agents\` or `<project>\.claude\agents\`     | `~\.copilot\agents\` or `<project>\.github\agents\`  | [agents/README.md](agents/)   |  |
| Hooks    | `~\.claude\hooks\` or `<project>\.claude\hooks\`       | `~\.copilot\hooks\` or `<project>\.github\hooks\`    | [hooks/README.md](hooks/)     |  |
| Settings | `~\.claude\settings.json` or `<project>\.claude\settings.json` | `~\.copilot\settings.json` or `<project>\.github\copilot\settings.json` | [settings/README.md](settings/) | Copilot permissions are not equivalent to Claude `permissions.allow`. |

### Available skills

| Skill | Claude Code | Copilot CLI | Description | Docs | Notes |
|-------|-------------|-------------|-------------|------|-------|
| `/ado-pr` | ✅ | ⚠️ | Create Azure DevOps PRs with standardized formatting | [README](skills/ado-pr/README.md) | Copilot PR creation only; no session capture. |
| `/ado-resume-pr` | ✅ | ❌ | Resume the Claude session that created a specific PR | [SKILL.claude.md](skills/ado-resume-pr/SKILL.claude.md) | Depends on Claude session database capture. |
| `/ado-pr-status` | ✅ | ❌ | List all tracked Claude PR sessions | [SKILL.claude.md](skills/ado-pr-status/SKILL.claude.md) | Depends on Claude session database capture. |
| `/ado-task` | ✅ | ✅ | Create, update, complete, and list Azure DevOps work items | [README](skills/ado-task/README.md) |  |
| `/cleanup-worktree` | ✅ | ✅ | Remove a git worktree and its local branch after PR merge | [README](skills/cleanup-worktree/README.md) |  |
| `/coverage-check` | ✅ | ⚠️ | Run diff coverage, classify uncovered chunks, and emit JSON findings | [README](skills/coverage-check/README.md) | Copilot support may require manual tool permissions. |
| `/doc-review` | ✅ | ⚠️ | Inspect the diff for missing/stale documentation; report-only JSON findings | [README](skills/doc-review/README.md) | Copilot support may require manual tool permissions. |
| `/implement` | ✅ | ⚠️ | Carry out an approved plan: branch, per-step commits, draft PR | [README](skills/implement/README.md) | Copilot support is partial. |
| `/log` | ✅ | ⚠️ | Append timestamped work entries to a weekly log | [SKILL.md](skills/log/SKILL.md) | Copilot path/config support is partial. |
| `/quick-pr` | ✅ | ⚠️ | Create a branch, commit, push, open a GitHub PR, merge, and clean up | [README](skills/quick-pr/README.md) | Copilot support may require manual shell permissions. |
| `/standards-check` | ✅ | ⚠️ | Discover repo standards, check the diff, and emit tiered JSON findings | [README](skills/standards-check/README.md) | Copilot support may require manual tool permissions. |
| `/weekly-status` | ✅ | ⚠️ | Generate weekly status from ADO + Todoist + local log | [README](skills/weekly-status/README.md) | Copilot path/config support is partial. |

### Available settings

| Preset | Claude Code | Copilot CLI | Description | Docs | Notes |
|--------|-------------|-------------|-------------|------|-------|
| `ado` | ✅ | 🛠️ | Azure DevOps MCP tool permissions — PRs, work items, iterations, repos | [ado.json](settings/claude/ado.json) | Copilot requires MCP setup and permission-model translation tracked by #19. |
| `base` | ✅ | ⚠️ | General-purpose permissions/preferences — file ops, git, grep | [base.json](settings/claude/base.json) | Copilot has a minimal JSON preset; shell permissions require launch flags. |
| `dotnet` | ✅ | 🛠️ | C#/.NET permissions and the C# LSP plugin | [dotnet.json](settings/claude/dotnet.json) | Copilot requires separate LSP/plugin or launch configuration tracked by #19. |
| `github` | ✅ | ⚠️ | GitHub CLI (`gh`) permissions and GitHub URL access | [github.json](settings/claude/github.json) | Copilot URL settings do not grant `gh` shell permissions. |
| `work-status` | ✅ | 🛠️ | MCP tool permissions for weekly status tracking (ADO + Todoist) | [work-status.json](settings/claude/work-status.json) | Copilot requires MCP setup plus path/tool permission translation tracked by #19. |

> Copilot settings support is marked `⚠️` because `settings\copilot\*.json` only covers Copilot JSON settings. Copilot shell/MCP/path permissions often require launch flags such as `--allow-tool`, `/mcp` setup, skill `allowed-tools`, agent `tools`, or hooks rather than Claude-style `permissions.allow` presets.

### Available hooks

| Hook | Claude Code | Copilot CLI | Description | Platform | Docs | Notes |
|------|-------------|-------------|-------------|----------|------|-------|
| `notify-windows` | ✅ | ✅ | Windows toast notifications for agent events | Windows | [README](hooks/notify-windows/README.md) |  |

> Agent-scoped PreToolUse hooks (e.g., the `verify-runner-bash-guard` that ships with the `verify-runner` agent) are registered via their owning agent's frontmatter — not via `settings.json` — and live alongside the agent's `.md` file. See `agents/<name>/` folders for the canonical pattern.

### Available agents

| Agent | Claude Code | Copilot CLI | Description | Tools | Docs | Notes |
|-------|-------------|-------------|-------------|-------|------|-------|
| `verify-runner` | ✅ | ⚠️ | Read-only verification subagent/custom agent that runs one verification check against the diff and returns JSON findings. | Claude: `Skill, Read, Grep, Glob, Bash`; Copilot: `read, search, execute` | [agents/verify-runner/](agents/verify-runner/) | Copilot lacks the Claude-style agent-frontmatter-scoped Bash guard. |

### Sync infrastructure (`bin/`)

The `bin\` folder contains executables that install artifacts into user-level agent config directories. Claude sync scripts target `~\.claude\`; Copilot PowerShell sync scripts target `~\.copilot\`. Claude scripts have both a PowerShell variant (`.ps1`) and a POSIX variant (no extension); Copilot sync is currently PowerShell-only.

| Script | Claude Code | Copilot CLI | Purpose | Notes |
|--------|-------------|-------------|---------|-------|
| `seiji-claude-install` | ✅ | ❌ | One-time PATH setup. Idempotent — re-running is safe. | Claude user-level PATH helper. |
| `seiji-claude-sync` | ✅ | ❌ | Wrapper. Runs every Claude per-category sync in order: skills → agents → hooks → settings. | Claude-only wrapper. |
| `seiji-claude-sync-skills` | ✅ | ❌ | Copies each skill to `~\.claude\skills\<name>\`. | Installs Claude-compatible source variants. |
| `seiji-claude-sync-agents` | ✅ | ❌ | Copies Claude agents to `~\.claude\agents\`. | Installs Claude-compatible source variants. |
| `seiji-claude-sync-hooks` | ✅ | ❌ | Copies Claude hook scripts to `~\.claude\hooks\<name>\`. | Does not register hooks in settings. |
| `seiji-claude-sync-settings` | ✅ | ❌ | Merges Claude settings into `~\.claude\settings.json`. | Preserves user scalar values. |
| `seiji-copilot-sync` | ❌ | ⚠️ | Copilot wrapper. Runs every Copilot PowerShell per-category sync in order: skills → agents → hooks → settings. | PowerShell workflow; POSIX is not included. |
| `seiji-copilot-sync-skills` | ❌ | ✅ | Copies Copilot-compatible skills to `~\.copilot\skills\<name>\`. | Installs Copilot-compatible source variants. |
| `seiji-copilot-sync-agents` | ❌ | ✅ | Copies Copilot custom agent profiles to `~\.copilot\agents\`. | Installs Copilot profiles as `.agent.md`. |
| `seiji-copilot-sync-hooks` | ❌ | ✅ | Copies Copilot hook scripts and JSON configs to `~\.copilot\hooks\`. | Rewrites hook config template paths. |
| `seiji-copilot-sync-settings` | ❌ | ✅ | Merges Copilot settings presets into `~\.copilot\settings.json`. | Applies Copilot JSON settings only. |

Quick start:

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-install.ps1
# Open a new PowerShell window so PATH refreshes
seiji-claude-sync
```

```sh
# Linux / macOS / Git Bash
./bin/seiji-claude-install
# Open a new shell so PATH refreshes
seiji-claude-sync
```

See [bin/README.md](bin/README.md) for prereqs (notably `jq` for the POSIX settings merge), the manual PATH-fallback, the symlink alternative, and the full settings merge rules (string-arrays union+dedupe+sort; object-arrays union+dedupe by deep equality; objects recurse; scalars preserve user value with a warning).

## Copilot CLI quick start

The Copilot sync path currently supports skills, agents, hooks, and settings on PowerShell:

```powershell
# Windows (PowerShell)
.\bin\seiji-copilot-sync.ps1 -DryRun
.\bin\seiji-copilot-sync.ps1
```

POSIX Copilot sync scripts are not included in this PR.

## Migration guide

1. Keep using Claude Code with the existing `seiji-claude-sync` workflow while Copilot support is added incrementally.
2. Use `AGENTS.md` as the canonical instruction file. `CLAUDE.md` is a symlink for Claude Code compatibility.
3. Use `SKILL.claude.md` and `SKILL.copilot.md` when a skill needs different frontmatter, paths, hook behavior, MCP tool names, or permission guidance.
4. Run both dry-runs before installing:

```powershell
.\bin\seiji-claude-sync.ps1 -DryRun
.\bin\seiji-copilot-sync.ps1 -DryRun
```

5. Check the availability tables before assuming a workflow is fully ported. `⚠️` means the item is partial or requires manual setup; `🛠️` means support is planned but not implemented.

### Symlink fallback

On Windows, creating symlinks may require Developer Mode or an elevated shell. If `CLAUDE.md` cannot be a symlink to `AGENTS.md`, copy `AGENTS.md` to `CLAUDE.md` and rerun validation:

```powershell
Copy-Item AGENTS.md CLAUDE.md -Force
.\bin\seiji-validate.ps1
```
