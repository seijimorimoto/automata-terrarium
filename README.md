# Seiji-Claude

A collection of reusable AI agent workflows for Claude Code and GitHub Copilot CLI: skills, agents, hooks, settings, and sync scripts.

## AI orchestrator support

This repo is transitioning from Claude Code-only artifacts to dual Claude Code and GitHub Copilot CLI support. `AGENTS.md` is the canonical instruction file; `CLAUDE.md` remains as a compatibility symlink for Claude Code.

Support tables use:

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support, manual setup required, or planned |

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

| Type     | Claude Code install location                           | Copilot CLI install location                         | Docs                          |
|----------|--------------------------------------------------------|-------------------------------------------------------|-------------------------------|
| Skills   | `~\.claude\skills\` or `<project>\.claude\skills\`     | `~\.copilot\skills\` or `<project>\.github\skills\`  | [skills/README.md](skills/)   |
| Agents   | `~\.claude\agents\` or `<project>\.claude\agents\`     | `~\.copilot\agents\` or `<project>\.github\agents\`  | [agents/README.md](agents/)   |
| Hooks    | `~\.claude\hooks\` or `<project>\.claude\hooks\`       | `~\.copilot\hooks\` or `<project>\.github\hooks\`    | [hooks/README.md](hooks/)     |
| Settings | `~\.claude\settings.json` or `<project>\.claude\settings.json` | `~\.copilot\settings.json` or `<project>\.github\copilot\settings.json` | [settings/README.md](settings/) |

### Available skills

| Skill | Claude Code | Copilot CLI | Description | Docs |
|-------|-------------|-------------|-------------|------|
| `/ado-pr` | ✅ | ⚠️ | Create Azure DevOps PRs with standardized formatting; Copilot PR creation only, no session capture | [README](skills/ado-pr/README.md) |
| `/ado-resume-pr` | ✅ | ❌ | Resume the Claude session that created a specific PR | [SKILL.claude.md](skills/ado-resume-pr/SKILL.claude.md) |
| `/ado-pr-status` | ✅ | ❌ | List all tracked Claude PR sessions | [SKILL.claude.md](skills/ado-pr-status/SKILL.claude.md) |
| `/ado-task` | ✅ | ✅ | Create, update, complete, and list Azure DevOps work items | [README](skills/ado-task/README.md) |
| `/cleanup-worktree` | ✅ | ✅ | Remove a git worktree and its local branch after PR merge | [README](skills/cleanup-worktree/README.md) |
| `/coverage-check` | ✅ | ⚠️ | Run diff coverage, classify uncovered chunks, and emit JSON findings | [README](skills/coverage-check/README.md) |
| `/doc-review` | ✅ | ⚠️ | Inspect the diff for missing/stale documentation; report-only JSON findings | [README](skills/doc-review/README.md) |
| `/implement` | ✅ | ⚠️ | Carry out an approved plan: branch, per-step commits, draft PR | [README](skills/implement/README.md) |
| `/log` | ✅ | ⚠️ | Append timestamped work entries to a weekly log | [SKILL.md](skills/log/SKILL.md) |
| `/quick-pr` | ✅ | ⚠️ | Create a branch, commit, push, open a GitHub PR, merge, and clean up | [README](skills/quick-pr/README.md) |
| `/standards-check` | ✅ | ⚠️ | Discover repo standards, check the diff, and emit tiered JSON findings | [README](skills/standards-check/README.md) |
| `/weekly-status` | ✅ | ⚠️ | Generate weekly status from ADO + Todoist + local log | [README](skills/weekly-status/README.md) |

### Available settings

| Preset | Claude Code | Copilot CLI | Description | Docs |
|--------|-------------|-------------|-------------|------|
| `ado` | ✅ | ⚠️ | Azure DevOps MCP tool permissions — PRs, work items, iterations, repos | [ado.json](settings/ado.json) |
| `base` | ✅ | ⚠️ | General-purpose permissions/preferences — file ops, git, grep | [base.json](settings/base.json) |
| `dotnet` | ✅ | ⚠️ | C#/.NET permissions and the C# LSP plugin | [dotnet.json](settings/dotnet.json) |
| `github` | ✅ | ⚠️ | GitHub CLI (`gh`) permissions and GitHub URL access | [github.json](settings/github.json) |
| `work-status` | ✅ | ⚠️ | MCP tool permissions for weekly status tracking (ADO + Todoist) | [work-status.json](settings/work-status.json) |

> Copilot settings support is marked `⚠️` because `settings\copilot\*.json` only covers Copilot JSON settings. Copilot shell/MCP/path permissions often require launch flags such as `--allow-tool`, `/mcp` setup, skill `allowed-tools`, agent `tools`, or hooks rather than Claude-style `permissions.allow` presets.

### Available hooks

| Hook | Claude Code | Copilot CLI | Description | Platform | Docs |
|------|-------------|-------------|-------------|----------|------|
| `notify-windows` | ✅ | ✅ | Windows toast notifications for agent events | Windows | [README](hooks/notify-windows/README.md) |

> Agent-scoped PreToolUse hooks (e.g., the `verify-runner-bash-guard` that ships with the `verify-runner` agent) are registered via their owning agent's frontmatter — not via `settings.json` — and live alongside the agent's `.md` file. See `agents/<name>/` folders for the canonical pattern.

### Available agents

| Agent | Claude Code | Copilot CLI | Description | Tools | Docs |
|-------|-------------|-------------|-------------|-------|------|
| `verify-runner` | ✅ | ⚠️ | Read-only verification subagent/custom agent that runs one verification check against the diff and returns JSON findings. | Copilot profile self-restricts commands; Copilot does not support the Claude-style agent-frontmatter-scoped Bash guard used here. | [agents/verify-runner/](agents/verify-runner/) |

### Sync infrastructure (`bin/`)

The `bin/` folder contains executables that install artifacts into user-level agent config directories. Claude sync scripts target `~\.claude\`; Copilot sync scripts are planned for `~\.copilot\`. Existing scripts have both a PowerShell variant (`.ps1`) and a POSIX variant (no extension).

| Script | Claude Code | Copilot CLI | Purpose |
|--------|-------------|-------------|---------|
| `seiji-claude-install` | ✅ | ❌ | One-time PATH setup. Idempotent — re-running is safe. |
| `seiji-claude-sync` | ✅ | ❌ | Wrapper. Runs every Claude per-category sync in order: skills → agents → hooks → settings. |
| `seiji-claude-sync-skills` | ✅ | ❌ | Copies each skill to `~\.claude\skills\<name>\`. |
| `seiji-claude-sync-agents` | ✅ | ❌ | Copies Claude agents to `~\.claude\agents\`. |
| `seiji-claude-sync-hooks` | ✅ | ❌ | Copies Claude hook scripts to `~\.claude\hooks\<name>\`. |
| `seiji-claude-sync-settings` | ✅ | ❌ | Merges Claude settings into `~\.claude\settings.json`. |
| `seiji-copilot-sync` | ❌ | ⚠️ | Copilot wrapper for implemented per-category sync scripts; skips categories not implemented yet. |
| `seiji-copilot-sync-skills` | ❌ | ✅ | Copies Copilot-compatible skills to `~\.copilot\skills\<name>\`. |
| `seiji-copilot-sync-agents` | ❌ | ✅ | Copies Copilot custom agent profiles to `~\.copilot\agents\`. |
| `seiji-copilot-sync-hooks` | ❌ | ✅ | Copies Copilot hook scripts and JSON configs to `~\.copilot\hooks\`. |
| `seiji-copilot-sync-settings` | ❌ | ✅ | Merges Copilot settings presets into `~\.copilot\settings.json`. |

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

POSIX Copilot sync scripts are planned after the PowerShell workflow settles.

## Migration guide

1. Keep using Claude Code with the existing `seiji-claude-sync` workflow while Copilot support is added incrementally.
2. Use `AGENTS.md` as the canonical instruction file. `CLAUDE.md` is a symlink for Claude Code compatibility.
3. Use `SKILL.claude.md` and `SKILL.copilot.md` when a skill needs different frontmatter, paths, hook behavior, MCP tool names, or permission guidance.
4. Run both dry-runs before installing:

```powershell
.\bin\seiji-claude-sync.ps1 -DryRun
.\bin\seiji-copilot-sync.ps1 -DryRun
```

5. Check the availability tables before assuming a workflow is fully ported. `⚠️` means the item is partial, requires manual setup, or is planned.

### Symlink fallback

On Windows, creating symlinks may require Developer Mode or an elevated shell. If `CLAUDE.md` cannot be a symlink to `AGENTS.md`, copy `AGENTS.md` to `CLAUDE.md` and rerun validation:

```powershell
Copy-Item AGENTS.md CLAUDE.md -Force
.\bin\seiji-validate.ps1
```
