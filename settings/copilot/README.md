# Copilot settings

Reusable GitHub Copilot CLI settings fragments and permission guidance.

## Available presets

These are Copilot CLI JSON settings fragments only. They do **not** replace Copilot's shell, MCP, URL, and path permission flags. Full permission-model translation is tracked by #19.

| Preset | File | Purpose | Notes |
|--------|------|---------|-------|
| Base | `base.json` | General Copilot preferences that can be merged into `~\.copilot\settings.json` | Does not grant shell command permissions. |
| GitHub | `github.json` | Allows GitHub URLs used by GitHub CLI and GitHub web/API workflows | Does not grant `gh` shell command permissions. Use `--allow-tool` for that. |

## Install

Use the sync script:

```powershell
.\bin\terrarium-sync-copilot-settings.ps1
```

Dry-run without writing:

```powershell
.\bin\terrarium-sync-copilot-settings.ps1 -DryRun
```

## Tool permission flags

Copilot CLI shell and MCP tool permissions are often supplied as launch flags rather than JSON settings. Examples:

```powershell
copilot --allow-tool 'shell(git status)' --allow-tool 'shell(git diff)' --allow-url 'https://github.com'
```

For broader workflows, prefer narrowly scoped command prefixes:

```powershell
copilot --allow-tool 'shell(git status)' --allow-tool 'shell(git log)' --allow-tool 'shell(gh pr view)'
```

Avoid `--allow-all` unless you are intentionally running in a trusted, non-interactive context.
