---
name: weekly-status
description: Generate a weekly status report from ADO, Todoist, and local work log
argument-hint: "[--week 2026-W12] [--file] [--format manager]"
---

# Weekly Status Report Generator

Generates a comprehensive weekly status report by aggregating data from Azure DevOps, Todoist, and local work log entries.

## Usage

```
/weekly-status
/weekly-status --week 2026-W12
/weekly-status --format manager
/weekly-status --file --format manager
```

## Parameters

- `--week` — ISO week to report on (default: current week). Format: `YYYY-WNN`.
- `--file` — Also write the report to a local file in the status repo.
- `--format manager` — Output concise bullets suitable for a manager update.

## Instructions

When this skill is invoked with `$ARGUMENTS`:

### 1. Load Configuration

Read `~/.claude/work-status-config.json`.

If missing, tell the user:

> Configuration file not found. Please create `~/.claude/work-status-config.json`:
> ```json
> {
>   "userEmail": "you@example.com",
>   "adoProject": "Your Project",
>   "adoTeam": "Your Team",
>   "statusRepoPath": "~/repos/my-status",
>   "defaultRepos": ["RepoName"],
>   "todoistProject": "Work",
>   "todoistLabels": ["work"]
> }
> ```

Then stop.

Required config keys for this skill: `userEmail`, `adoProject`, `defaultRepos`.

### 2. Determine Week Range

Parse `--week` argument or calculate the current ISO week. Derive:
- **weekLabel**: `YYYY-WNN`
- **monday**: start date (YYYY-MM-DD)
- **sunday**: end date (YYYY-MM-DD)

### 3. Gather Data (run independent sources in parallel)

#### 3a. ADO Commits & PRs

For each repo in `defaultRepos`:

1. Use `mcp__ado__repo_search_commits` with:
   - `projectName`: from config `adoProject`
   - `searchText`: config `userEmail`
   - `fromDate`: monday
   - `toDate`: sunday + 1 day (to include sunday's commits)
2. For any commits found, use `mcp__ado__repo_list_pull_requests_by_commits` to find associated PRs.

#### 3b. ADO Work Items

Use `mcp__ado__wit_my_work_items` to get work items assigned to the user. Filter results to items that were active or updated during the target week.

#### 3c. Local Work Log

Read the file `<statusRepoPath>/work-log/<weekLabel>.md` if it exists. Parse the markdown table rows into entries.

#### 3d. Todoist Completed Tasks

1. Use `mcp__todoist__find-projects` to find the project named in config `todoistProject`.
2. **Recursively collect all descendant project IDs**: walk the project tree to find all children, grandchildren, etc. of the matched project.
3. For each project ID (parent + all descendants), use `mcp__todoist__find-completed-tasks` with:
   - `projectId`: the project ID
   - `since`: monday date
   - `until`: sunday date + 1 day
   - `getBy`: `"completion"`
4. If `todoistLabels` is configured, also use label filtering to include tasks matching those labels regardless of project.
5. Deduplicate tasks that appear in both project and label results.

### 4. Synthesize Report

Combine all gathered data into a single report:

1. **Group by project/feature area** — not by source. Determine grouping from:
   - ADO work item area paths
   - PR target repos
   - Todoist project names
   - Work log entry content
2. **Deduplicate** — entries that appear in multiple sources (e.g., a commit and a work log entry about the same work) should be merged into one line.
3. **Format** the report using this structure:

```markdown
# Weekly Status — <weekLabel> (<Mon date> – <Sun date>)

## <Feature Area / Project 1>
- Completed item description (PR #123)
- Another item (ADO #456)

## <Feature Area / Project 2>
- Item description

## Ongoing / In Progress
- Items started but not completed

## Todoist Tasks Completed
- Task descriptions not covered above
```

If `--format manager` is specified, use a more concise format:
```markdown
# Status Update — <weekLabel>

**Completed:**
- Concise bullet 1
- Concise bullet 2

**In Progress:**
- Concise bullet

**Blocked / Needs Attention:**
- (if any)
```

### 5. Archive

Always write the report to `<statusRepoPath>/weekly-statuses/<weekLabel>.md`, creating directories as needed.

### 6. Output

- Display the full report to the user.
- If `--file` was specified, confirm the local file path.
- Prompt: **"Any items have notable impact worth capturing? You can use `/log <note> --impact \"...\"` to annotate them."**

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `userEmail` | Yes | — | Your email for filtering ADO commits |
| `adoProject` | Yes | — | Azure DevOps project name |
| `adoTeam` | No | — | ADO team name (for sprint resolution) |
| `statusRepoPath` | No | `~/.claude/work-status/` | Root directory for status data |
| `defaultRepos` | Yes | — | List of ADO repo names to search |
| `todoistProject` | No | — | Todoist project name to filter tasks (recursive) |
| `todoistLabels` | No | — | Todoist label names to include |
