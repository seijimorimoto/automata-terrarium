# Weekly Status Skill

Generates a weekly status report by aggregating data from multiple sources: Azure DevOps commits/PRs/work items, Todoist completed tasks, and local work log entries.

## Prerequisites

1. **Azure DevOps MCP server** — must be configured and connected in your runtime.

   Verify by checking that Azure DevOps MCP tools are available in your session.

2. **Todoist MCP server** — must be configured and connected in your runtime.

   Verify by checking that Todoist MCP tools are available in your session.

3. **Configuration file** — create `~\.agents\work-status-config.json`:

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
/weekly-status                                          # Current week, display + archive
/weekly-status --week 2026-W12                          # Specific ISO week
/weekly-status --date 2026-03-16                        # Week containing this date
/weekly-status --from 2026-03-16 --to 2026-03-22       # Custom date range (inclusive)
/weekly-status --output console                         # Display only, no file written
/weekly-status --output file                            # Archive only, no console display
/weekly-status --format manager                         # Concise bullets for manager
/weekly-status --output console --format manager        # Display manager format only
```

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--week YYYY-WNN` | ISO week to report on | Current week |
| `--date YYYY-MM-DD` | Resolves to the ISO week containing this date | — |
| `--from` / `--to` | Arbitrary date range (inclusive both ends) | — |
| `--output` | `console`, `file`, or `both` | `both` |
| `--format` | `detailed`, `manager`, or `both` | `both` |

Time range options (`--week`, `--date`, `--from`/`--to`) are mutually exclusive.

## Output

The skill produces a markdown report grouped by feature area, not by data source. By default (`--output both`), it displays the report and archives it to `<statusRepoPath>\weekly-statuses\<startDate>_to_<endDate>.md`.

### Example Output (Detailed)

```markdown
# Weekly Status — 2026-W12 (2026-03-16 – 2026-03-22)

## ReadServices
- **[PR #4521](https://dev.azure.com/org/project/_git/repo/pullrequest/4521)**: Add caching layer for tenant metadata (12 files changed) — Completed
  - **Summary:** Introduced a distributed cache for tenant metadata lookups to reduce database load.
  - **Impact:** Reduced p95 latency for tenant resolution from 120ms to 15ms.
- **[#78901](https://dev.azure.com/org/project/_workitems/edit/78901)**: Fix token expiry crash in auth middleware (Bug, Resolved, ReadServices\Auth)
  - Token refresh logic was not handling clock skew; added a 5-minute buffer.

## NotificationServices
- [Review Q1 OKR draft](https://todoist.com/app/task/123456) (Todoist, Work)
- Added configuration files for each cloud environment — Impact: Enables per-region feature flags

## Active This Week
- **[#78902](https://dev.azure.com/org/project/_workitems/edit/78902)**: Investigate latency regression in event pipeline (Task, Active) — updated 2026-03-18
  - Initial profiling shows serialization bottleneck in message handler.

## Stale (No Recent Updates)
> These items are assigned to you but have not been updated during this period.
- [#45001](https://dev.azure.com/org/project/_workitems/edit/45001): Update API versioning strategy doc
- [#45002](https://dev.azure.com/org/project/_workitems/edit/45002): Deprecate legacy notification endpoint
```

### Example Output (Manager)

```markdown
# Status Update — 2026-W12

**Completed:**
- Added caching layer for tenant metadata, reducing p95 latency from 120ms to 15ms ([PR #4521](https://dev.azure.com/org/project/_git/repo/pullrequest/4521))
- Fixed token expiry crash in auth middleware ([#78901](https://dev.azure.com/org/project/_workitems/edit/78901))

**In Progress:**
- Investigating latency regression in event pipeline — serialization bottleneck identified ([#78902](https://dev.azure.com/org/project/_workitems/edit/78902))

**Blocked / Needs Attention:**
- (none)
```

## Data Sources

| Source | MCP Tools Used | What It Captures |
|--------|---------------|------------------|
| ADO Commits | `mcp__ado__repo_search_commits` | Commits by your email in configured repos |
| ADO PRs | `mcp__ado__repo_list_pull_requests_by_commits` | PRs associated with your commits (title, status, files changed, description details) |
| ADO Work Items | `mcp__ado__wit_my_work_items` | Items assigned to you (split into active vs. stale) |
| Todoist | `mcp__todoist__find-projects`, `mcp__todoist__find-completed-tasks` | Completed tasks in your work project (recursive) |
| Work Log | Local file read | Manual `/log` entries for the week |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Configuration file not found" | Create `~\.agents\work-status-config.json` per the Prerequisites section |
| No ADO data returned | Verify `userEmail` matches your ADO identity and `defaultRepos` lists correct repo names |
| No Todoist data returned | Verify `todoistProject` matches an existing project name exactly (case-sensitive) |
| Missing work log entries | Use `/log` to add entries before generating the status |
| Report not archived | Check that `--output` is `file` or `both` (default). `--output console` skips archiving |
| Stale items appearing | These are items assigned to you in ADO that were not updated during the report period. Reassign or close them if no longer relevant |
