# Weekly Status Skill

Generates a weekly status report by aggregating data from multiple sources: Azure DevOps PRs/work items, Todoist completed tasks, WorkIQ candidate insights, and local work log entries.

## Prerequisites

1. **Azure DevOps MCP server** — must be configured and connected in your runtime.

   Verify by checking that Azure DevOps MCP tools are available in your session.

2. **Todoist MCP server** — must be configured and connected in your runtime.

   Verify by checking that Todoist MCP tools are available in your session.

3. **WorkIQ MCP server** — optional but recommended when available. The skill uses it to gather review-gated candidate insights from Microsoft 365 sources such as email, Teams, meetings, and files. No additional configuration key is required.

   Verify by checking that WorkIQ MCP tools are available in your session.

4. **Configuration file** — create `~\.agents\work-status-config.json`:

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

The skill produces a markdown report grouped by ADO work stream when work item hierarchy is available, with PRs, Todoist tasks, WorkIQ candidate insights, and work log entries attached as supporting evidence after review. By default (`--output both`), it displays the report and archives it to `<statusRepoPath>\weekly-statuses\<startDate>_to_<endDate>.md`.

### Example Output (Detailed)

```markdown
# Weekly Status — 2026-W12 (2026-03-16 – 2026-03-22)

## Highlights
- Fixed the auth token expiry crash and identified the next latency-regression validation step.

## ReadServices
- **[#78901](https://dev.azure.com/org/project/_workitems/edit/78901)**: Fix token expiry crash in auth middleware (Bug, Resolved, ReadServices\Auth)
  - **Progress this week:** Completed the token refresh fix and linked implementation PR.
  - **Evidence:** [PR #4521](https://dev.azure.com/org/project/_git/repo/pullrequest/4521), ADO discussion update, Todoist completion.
  - **Impact:** Added a 5-minute clock-skew buffer to prevent token expiry crashes.

## NotificationServices
- **[#78902](https://dev.azure.com/org/project/_workitems/edit/78902)**: Investigate latency regression in event pipeline (Task, Active, NotificationServices)
  - **Progress this week:** Profiling identified serialization as the likely bottleneck.
  - **Evidence:** ADO comment from 2026-03-18, WorkIQ Teams discussion from 2026-03-19, [Review Q1 OKR draft](https://todoist.com/app/task/123456), work log entry.
  - **Next:** Validate the serialization fix candidate next week.

```

### Example Output (Manager)

```markdown
# Status Update — 2026-W12

**Completed:**
- Fixed token expiry crash in auth middleware by adding clock-skew handling ([#78901](https://dev.azure.com/org/project/_workitems/edit/78901), [PR #4521](https://dev.azure.com/org/project/_git/repo/pullrequest/4521))

**In Progress:**
- Investigating latency regression in event pipeline — serialization bottleneck identified ([#78902](https://dev.azure.com/org/project/_workitems/edit/78902))

**Blocked / Needs Attention:**
- (none)
```

## Data Sources

| Source | MCP Tools Used | What It Captures |
|--------|---------------|------------------|
| ADO PRs | `mcp__ado__repo_list_pull_requests_by_repo_or_project` | PRs authored by you in configured repos, including completed and active weekly activity |
| ADO Work Items | `mcp__ado__wit_my_work_items`, `mcp__ado__wit_get_work_items_batch_by_ids`, work item comment tools | Assigned items, hierarchy, linked PRs/artifacts, descriptions, and week-bounded comments |
| Todoist | `mcp__todoist__find-projects`, `mcp__todoist__find-completed-tasks` | Completed tasks in your work project (recursive) |
| WorkIQ | `mcp__workiq__ask` | Review-gated candidate insights from week-bounded email, Teams, meeting, and file activity |
| Work Log | Local file read | Manual `/log` entries for the week |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Configuration file not found" | Create `~\.agents\work-status-config.json` per the Prerequisites section |
| No ADO data returned | Verify `userEmail` matches your ADO identity and `defaultRepos` lists correct repo names |
| No Todoist data returned | Verify `todoistProject` matches an existing project name exactly (case-sensitive) |
| No WorkIQ data returned | Confirm the WorkIQ MCP server is available. The skill should continue without WorkIQ candidates if the source is unavailable |
| Missing work log entries | Use `/log` to add entries before generating the status |
| Report not archived | Check that `--output` is `file` or `both` (default). `--output console` skips archiving |
| Missing ADO comments or hierarchy | Confirm the available ADO MCP tools can fetch work item comments and expanded relations; if unavailable, the skill should continue with the fields it can fetch and call out the missing evidence |
