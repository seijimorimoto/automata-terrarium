# Seiji-Claude

A collection of custom Claude Code skills, hooks, and settings.

## Setup

After cloning, install the git pre-commit hook to enforce the PR-only workflow:

```bash
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

Each directory contains its own README with setup instructions. To use any item, copy or symlink it into your `~/.claude/` configuration directory.

### Quick reference

| Type     | Install location              | Docs                          |
|----------|-------------------------------|-------------------------------|
| Skills   | `~/.claude/skills/`           | [skills/README.md](skills/)   |
| Hooks    | `~/.claude/settings.json`     | [hooks/README.md](hooks/)     |
| Settings | `~/.claude/settings.json`     | [settings/README.md](settings/) |
