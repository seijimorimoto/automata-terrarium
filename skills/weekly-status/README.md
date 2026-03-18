# Weekly Status Skill

Generates a weekly status report by aggregating data from multiple sources: Azure DevOps commits/PRs/work items, Todoist completed tasks, and local work log entries.

## Prerequisites

1. **Azure DevOps MCP server** — must be configured and connected in Claude Code.

   Verify by checking that `mcp__ado__*` tools are available in your session.

2. **Todoist MCP server** — must be configured and connected in Claude Code.

   Verify by checking that `mcp__todoist__*` tools are available in your session.

3. **Configuration file** — create `~\.claude\work-status-config.json`:

   ```json
   {
     "userEmail": "you@example.com",
     "adoProject": "Your Project",
     "adoTeam": "Your Team",
     "statusRepoPath": "~/repos/my-status",
     "defaultRepos": ["RepoName"],
     "todoistProject": "Work",
     "todoistLabels": ["work"]
   }
   ```

## Installation

Copy the skill folder into your `.claude\skills\` directory:

```powershell
# Windows (PowerShell) — user-level
Copy-Item -Recurse skills\weekly-status ~\.claude\skills\

# Windows (PowerShell) — project-level
Copy-Item -Recurse skills\weekly-status <project-root>\.claude\skills\
```

```sh
# Linux / macOS — user-level
cp -r skills/weekly-status ~/.claude/skills/

# Linux / macOS — project-level
cp -r skills/weekly-status <project-root>/.claude/skills/
```

## Usage

```
/weekly-status                          # Current week, all sources
/weekly-status --week 2026-W12          # Specific week
/weekly-status --format manager         # Concise bullets for manager
/weekly-status --file --format manager  # Save to file + concise format
```

## Output

The skill produces a markdown report grouped by feature area, not by data source. It always archives the report to `<statusRepoPath>\weekly-statuses\<week>.md`.

### Example Output

```markdown
# Weekly Status — 2026-W12 (2026-03-16 – 2026-03-22)

## ReadServices
- Implemented caching layer for tenant metadata (PR #4521)
- Fixed token expiry crash in auth middleware (ADO #78901)

## NotificationServices
- Added configuration files for each cloud environment

## Ongoing / In Progress
- Investigating latency regression in event pipeline

## Todoist Tasks Completed
- Review Q1 OKR draft
- Update team wiki with onboarding steps
```

## Data Sources

| Source | MCP Tools Used | What It Captures |
|--------|---------------|------------------|
| ADO Commits | `mcp__ado__repo_search_commits` | Commits by your email in configured repos |
| ADO PRs | `mcp__ado__repo_list_pull_requests_by_commits` | PRs associated with your commits |
| ADO Work Items | `mcp__ado__wit_my_work_items` | Items assigned to you |
| Todoist | `mcp__todoist__find-projects`, `mcp__todoist__find-completed-tasks` | Completed tasks in your work project (recursive) |
| Work Log | Local file read | Manual `/log` entries for the week |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Configuration file not found" | Create `~\.claude\work-status-config.json` per the Prerequisites section |
| No ADO data returned | Verify `userEmail` matches your ADO identity and `defaultRepos` lists correct repo names |
| No Todoist data returned | Verify `todoistProject` matches an existing project name exactly (case-sensitive) |
| Missing work log entries | Use `/log` to add entries before generating the status |
