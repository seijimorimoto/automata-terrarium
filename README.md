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

## Structure

```
skills/    - Custom slash-command skills (.md files)
hooks/     - Event-driven hook scripts
settings/  - Reusable settings snippets and configurations
```

## Usage

Each directory contains its own README with setup instructions. To use any item, copy or symlink it into your target project's `.claude/skills/` directory.

### Quick reference

> **Paths:** Shown in Windows format (`\`). On Linux/macOS, use forward slashes (`/`) instead.

| Type     | Install location                                       | Docs                          |
|----------|--------------------------------------------------------|-------------------------------|
| Skills   | `~\.claude\skills\` or `<project>\.claude\skills\`     | [skills/README.md](skills/)   |
| Hooks    | `~\.claude\hooks\` or `<project>\.claude\hooks\`       | [hooks/README.md](hooks/)     |
| Settings | `~\.claude\settings.json` or `<project>\.claude\settings.json` | [settings/README.md](settings/) |

### Available skills

| Skill | Description | Docs |
|-------|-------------|------|
| `/ado-pr` | Create Azure DevOps PRs with standardized formatting | [README](skills/ado-pr/README.md) |
| `/ado-resume-pr` | Resume the Claude session that created a specific PR | [SKILL.md](skills/ado-resume-pr/SKILL.md) |
| `/ado-pr-status` | List all tracked PRs linked to Claude sessions | [SKILL.md](skills/ado-pr-status/SKILL.md) |

### Available settings

| Preset | Description | Docs |
|--------|-------------|------|
| `base` | General-purpose permissions — file ops, git, grep | [base.json](settings/base.json) |
| `dotnet` | C#/.NET permissions and the C# LSP plugin | [dotnet.json](settings/dotnet.json) |

### Available hooks

| Hook | Description | Platform | Docs |
|------|-------------|----------|------|
| `notify-windows` | Windows toast notifications for Claude Code events | Windows | [README](hooks/notify-windows/README.md) |
