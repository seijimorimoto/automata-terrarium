# Skills

Reusable skills for Claude Code and GitHub Copilot CLI.

Use shared `SKILL.md` when the same entrypoint works for both runtimes. Prefer runtime-neutral wording, agent-neutral paths, and descriptive references to tools or capabilities before splitting variants. Use `SKILL.claude.md` and `SKILL.copilot.md` only when a runtime difference cannot be represented cleanly in one shared file.

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

## Available Skills

| Skill | Claude Code | Copilot CLI | Description | Docs | Notes |
|-------|-------------|-------------|-------------|------|-------|
| `/ado-pr` | ✅ | ✅ | Create Azure DevOps PRs with standardized formatting | [README](ado-pr/README.md) | Shared skill. |
| `/ado-pr-fix` | ✅ | ✅ | Analyze and address Azure DevOps PR review comments with approval gates | [README](ado-pr-fix/README.md) | Requires Azure DevOps MCP PR thread tools. |
| `/ado-task` | ✅ | ✅ | Create, update, complete, and list Azure DevOps work items | [README](ado-task/README.md) | Requires Azure DevOps MCP setup. |
| `/cleanup-worktree` | ✅ | ✅ | Remove a git worktree and its local branch after PR merge | [README](cleanup-worktree/README.md) | Uses local git commands only. |
| `/coverage-check` | ✅ | ✅ | Run diff coverage, classify uncovered chunks, and emit JSON findings | [README](coverage-check/README.md) | Requires a project coverage tool when coverage is expected. |
| `/doc-review` | ✅ | ✅ | Inspect the diff for missing or stale documentation and emit report-only findings | [README](doc-review/README.md) | Uses local git diff context. |
| `/implement` | ✅ | ✅ | Implement a plan from a session, file, issue, PR, work item, or readable reference | [README](implement/README.md) | Defaults to repo checks; native or equivalent checks are best-effort. |
| `/log` | ✅ | ✅ | Append timestamped work entries to the current week's log | [SKILL.md](log/SKILL.md) | Uses agent-neutral `~\.agents\` work-status paths. |
| `/quick-pr` | ✅ | ✅ | Create a branch, commit, push, open a GitHub PR, optionally merge, and clean up | [README](quick-pr/README.md) | Requires GitHub CLI authentication. |
| `/standards-check` | ✅ | ✅ | Discover project instructions and standards files, check the diff, and emit tiered JSON findings | [README](standards-check/README.md) | Uses local git and helper scripts. |
| `/weekly-status` | ✅ | ✅ | Generate weekly status from Azure DevOps, Todoist, WorkIQ candidate insights, and local work logs | [README](weekly-status/README.md) | Requires ADO/Todoist MCP setup; uses WorkIQ when available. |

## Installation

Install user-level skills with the sync scripts, which copy the correct source variant as `SKILL.md`.

- **Claude project-level** (one project): `<project-root>\.claude\skills\`
- **Claude user-level** (all projects): `~\.claude\skills\`
- **Copilot project-level** (one project): `<project-root>\.github\skills\`
- **Copilot user-level** (all projects): `~\.copilot\skills\`

```powershell
# Windows (PowerShell)
.\bin\terrarium-sync-claude-skills.ps1
.\bin\terrarium-sync-copilot-skills.ps1
```

```sh
# Linux / macOS / POSIX
./bin/terrarium-sync-claude-skills
# POSIX Copilot sync is tracked by #21.
```

## Creating a New Skill

1. Create `skills\<name>\`.
2. Add `SKILL.md` for shared behavior, or target-specific `SKILL.claude.md` and `SKILL.copilot.md` files only when runtime differences cannot be expressed cleanly in one file.
3. Add `skills\<name>\README.md` with prerequisites, install locations, sync-script steps, and runtime-specific registration or activation steps.
4. Keep shared text runtime-neutral. Put runtime-specific hooks, MCP naming, permissions, or paths under clearly labeled runtime subsections.
5. Update the Available Skills tables in this README and the repo-level README.
