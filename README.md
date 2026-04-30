# Seiji-Claude

A collection of custom Claude Code skills, hooks, and settings.

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
skills/    - Custom slash-command skills (.md files)
agents/    - Custom subagent definitions (tool-restricted markdown files)
hooks/     - Event-driven hook scripts
settings/  - Reusable settings snippets and configurations
bin/       - Sync executables that install skills/agents/hooks/settings to ~\.claude\
```

## Usage

Each directory contains its own README with setup instructions. To use any item, copy or symlink it into your target project's `.claude/skills/` directory.

### Quick reference

> **Paths:** Shown in Windows format (`\`). On Linux/macOS, use forward slashes (`/`) instead.

| Type     | Install location                                       | Docs                          |
|----------|--------------------------------------------------------|-------------------------------|
| Skills   | `~\.claude\skills\` or `<project>\.claude\skills\`     | [skills/README.md](skills/)   |
| Agents   | `~\.claude\agents\` or `<project>\.claude\agents\`     | [agents/README.md](agents/)   |
| Hooks    | `~\.claude\hooks\` or `<project>\.claude\hooks\`       | [hooks/README.md](hooks/)     |
| Settings | `~\.claude\settings.json` or `<project>\.claude\settings.json` | [settings/README.md](settings/) |

### Available skills

| Skill | Description | Docs |
|-------|-------------|------|
| `/ado-pr` | Create Azure DevOps PRs with standardized formatting | [README](skills/ado-pr/README.md) |
| `/ado-resume-pr` | Resume the Claude session that created a specific PR | [SKILL.md](skills/ado-resume-pr/SKILL.md) |
| `/ado-pr-status` | List all tracked PRs linked to Claude sessions | [SKILL.md](skills/ado-pr-status/SKILL.md) |
| `/ado-task` | Create, update, complete, and list Azure DevOps work items | [README](skills/ado-task/README.md) |
| `/cleanup-worktree` | Remove a git worktree and its local branch after PR merge | [README](skills/cleanup-worktree/README.md) |
| `/coverage-check` | Run diff coverage, classify each uncovered chunk (`pure_logic` / `trivial` / `untestable` / `generated`); emits JSON findings | [README](skills/coverage-check/README.md) |
| `/doc-review` | Inspect the diff for missing/stale documentation; report-only JSON findings | [README](skills/doc-review/README.md) |
| `/implement` | Carry out an approved plan: branch, per-step commits, draft PR | [README](skills/implement/README.md) |
| `/log` | Append timestamped work entries to a weekly log | [SKILL.md](skills/log/SKILL.md) |
| `/quick-pr` | Create a branch, commit, push, open a GitHub PR, merge, and clean up | [README](skills/quick-pr/README.md) |
| `/standards-check` | Discover repo standards files, extract rules, check the diff against them; emits tiered JSON findings | [README](skills/standards-check/README.md) |
| `/weekly-status` | Generate weekly status from ADO + Todoist + local log | [README](skills/weekly-status/README.md) |

### Available settings

| Preset | Description | Docs |
|--------|-------------|------|
| `ado` | Azure DevOps MCP tool permissions — PRs, work items, iterations, repos | [ado.json](settings/ado.json) |
| `base` | General-purpose permissions — file ops, git, grep | [base.json](settings/base.json) |
| `dotnet` | C#/.NET permissions and the C# LSP plugin | [dotnet.json](settings/dotnet.json) |
| `github` | GitHub CLI (`gh`) permissions — PR creation, merging, and status | [github.json](settings/github.json) |
| `work-status` | MCP tool permissions for weekly status tracking (ADO + Todoist) | [work-status.json](settings/work-status.json) |

### Available hooks

| Hook | Description | Platform | Docs |
|------|-------------|----------|------|
| `notify-windows` | Windows toast notifications for Claude Code events | Windows | [README](hooks/notify-windows/README.md) |
| `verify-runner-bash-guard` | PreToolUse hook restricting `verify-runner` subagent Bash to a read-only allowlist; falls back to no-op when context can't be detected | Cross-platform | [README](hooks/verify-runner-bash-guard/README.md) |

### Available agents

| Agent | Description | Tools | Docs |
|-------|-------------|-------|------|
| `verify-runner` | Read-only verification subagent. Runs one verification skill (e.g., `/standards-check`, `/doc-review`, `/coverage-check`, `/review`, `/security-review`, `/simplify`) against the diff and returns findings as JSON. Cannot modify files. | `Skill, Read, Grep, Glob, Bash` | [agents/verify-runner.md](agents/verify-runner.md) · [agents/README.md](agents/README.md) |

### Sync infrastructure (`bin/`)

The `bin/` folder contains executables that install everything in this repo into your user-level Claude config (`~\.claude\`). Each script has both a PowerShell variant (`.ps1`) and a POSIX variant (no extension).

| Script | Purpose |
|--------|---------|
| `seiji-claude-install` | One-time PATH setup. Idempotent — re-running is safe. |
| `seiji-claude-sync` | Wrapper. Runs every per-category sync in order: skills → agents → hooks → settings. |
| `seiji-claude-sync-skills` | Copies each subfolder of `skills/` to `~\.claude\skills\<name>\`. |
| `seiji-claude-sync-agents` | Copies each `agents/*.md` (skipping README) to `~\.claude\agents\<name>.md`. |
| `seiji-claude-sync-hooks` | Copies each subfolder of `hooks/` to `~\.claude\hooks\<name>\`. |
| `seiji-claude-sync-settings` | Merges every `settings\*.json` into `~\.claude\settings.json` per the documented merge rules. |

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
