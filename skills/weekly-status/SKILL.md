---
name: weekly-status
description: Generate a weekly status report from ADO, Todoist, and local work log
argument-hint: "[--week 2026-W12] [--date 2026-03-16] [--from DATE --to DATE] [--output console|file|both] [--format detailed|manager|both]"
---

# Weekly Status Report Generator

Generates a comprehensive weekly status report by aggregating data from Azure DevOps, Todoist, and local work log entries.

## Usage

```
/weekly-status
/weekly-status --week 2026-W12
/weekly-status --date 2026-03-16
/weekly-status --from 2026-03-16 --to 2026-03-22
/weekly-status --output console --format manager
/weekly-status --output file --format detailed
```

## Parameters

- `--week` — ISO week to report on. Format: `YYYY-WNN`. Default: current week.
- `--date` — A specific date; resolves to the ISO week containing that date. Format: `YYYY-MM-DD`.
- `--from` / `--to` — Arbitrary date range, **inclusive at both ends**. Format: `YYYY-MM-DD`.
- `--output` — Where the report goes. Values: `console`, `file`, `both` (default: `both`).
  - `console` — display only, no file written.
  - `file` — write to archive only, no console display.
  - `both` — display to console AND archive to file.
- `--format` — Which report style(s) to produce. Values: `detailed`, `manager`, `both` (default: `both`).
  - `detailed` — full grouped report with rich detail.
  - `manager` — concise bullets for manager updates.
  - `both` — produce both formats. When output includes console, display both. When output includes file, archive the detailed version.

The three time range options (`--week`, `--date`, `--from`/`--to`) are **mutually exclusive**. If none is specified, the current ISO week is used.

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

### 2. Determine Date Range

Parse the time range argument from `$ARGUMENTS`. The three options are mutually exclusive:

1. **`--week YYYY-WNN`** — resolve to Monday and Sunday of that ISO week.
2. **`--date YYYY-MM-DD`** — resolve to the ISO week containing that date (Monday–Sunday).
3. **`--from YYYY-MM-DD --to YYYY-MM-DD`** — use directly as the date range.
4. **No argument** — use the current ISO week (Monday–Sunday).

All dates are interpreted in the user's **local timezone** (system clock).

Derive:
- **weekLabel**: `YYYY-WNN` (for `--from`/`--to`, derive from the start date)
- **startDate**: first day of the range (YYYY-MM-DD)
- **endDate**: last day of the range (YYYY-MM-DD), inclusive
- **queryEndDate**: endDate + 1 day — used for API calls that treat the upper bound as exclusive (e.g., ADO `toDate`, Todoist `until`)

**Archive filename**: Always `<startDate>_to_<endDate>.md` (e.g., `2026-03-16_to_2026-03-22.md`), regardless of which parameter was used.

### 3. Gather Data (run independent sources in parallel)

#### 3a. ADO Commits & PRs

For each repo in `defaultRepos`:

1. Use `mcp__ado__repo_search_commits` with:
   - `projectName`: from config `adoProject`
   - `searchText`: config `userEmail`
   - `fromDate`: startDate
   - `toDate`: queryEndDate
2. For any commits found, use `mcp__ado__repo_list_pull_requests_by_commits` to find associated PRs.
3. For each PR found, extract:
   - **Title**
   - **Status**: completed or active
   - **Number of files changed**
   - **Target branch**: include only if it differs from the repo's default branch (main/master)
   - **URL**: use `_links.web.href` from the tool response (the web UI link)
   - **Summary and Impact**: parse the PR description body to extract Summary, Key Changes, and Impact sections (following the `/ado-pr` template format)

Since repos using squash-merge have a 1:1 mapping between PRs and commits, do **not** list individual commits under PRs.

#### 3b. ADO Work Items

**Step 1 — Fetch item IDs and basic fields:**

Use `mcp__ado__wit_my_work_items` to get work items assigned to the user. This returns IDs, titles, types, states, area paths, and `ChangedDate`.

**Step 2 — Classify as active or stale:**

- **Active This Week**: items with `ChangedDate` within the report date range (startDate to endDate, inclusive).
- **Stale (No Recent Updates)**: assigned items whose `ChangedDate` falls outside the report date range.

For each item, note:
- **Title**, **Type**, **State**, **Area Path**
- **ChangedDate**
- **URL**: use `_links.html.href` from the tool response (the web UI link, **not** the `url` field which points to the REST API)

**Step 3 — Fetch descriptions only for active items:**

For items classified as **Active This Week**, use `mcp__ado__wit_get_work_items_batch_by_ids` to fetch `System.Description` in batches of **10 items at a time** (to stay within tool response limits). Extract a brief summary of key details from the description.

Do **not** fetch descriptions for stale items — they only need ID, title, and URL.

> **Why batches of 10?** The `System.Description` field contains rich HTML that can be very large. Fetching too many items with descriptions in a single call can exceed tool response token limits, causing failures or requiring workarounds like Python parsing scripts.

#### 3c. Local Work Log

Read the file `<statusRepoPath>/work-log/<startDate>_to_<endDate>.md` if it exists. Parse the markdown table rows into entries. Include the impact annotation inline if present.

#### 3d. Todoist Completed Tasks

1. Use `mcp__todoist__find-projects` to find the project named in config `todoistProject`.
2. **Recursively collect all descendant project IDs**: walk the project tree to find all children, grandchildren, etc. of the matched project.
3. For each project ID (parent + all descendants), use `mcp__todoist__find-completed-tasks` with:
   - `projectId`: the project ID
   - `since`: startDate
   - `until`: queryEndDate (endDate + 1 day, since `until` is exclusive)
   - `getBy`: `"completion"`
4. If `todoistLabels` is configured, also use label filtering to include tasks matching those labels regardless of project.
5. Deduplicate tasks that appear in both project and label results.
6. For each task, capture:
   - **Content** (task title)
   - **Project name**
   - **URL**: use the `url` field from the task object in the tool response

### 4. Synthesize Report

Combine all gathered data into a single report.

#### Grouping and Deduplication

1. **Group by project/feature area** — not by source. Determine grouping from:
   - ADO work item area paths
   - PR target repos
   - Todoist project names
   - Work log entry content
2. **Deduplicate** — entries that appear in multiple sources (e.g., a commit and a work log entry about the same work) should be merged into one line.

#### Hyperlinked References

Use web UI URLs from tool responses — **never** use the `url` field for ADO items (it points to the REST API and renders as raw JSON):
- ADO Work Items: `[#78901]({_links.html.href})` — the web UI edit page
- ADO PRs: `[PR #123]({_links.web.href})` — the web UI PR page
- Todoist tasks: `[task title]({url})` — Todoist's `url` field is already a web link

#### Detailed Format

```markdown
# Weekly Status — <weekLabel> (<startDate> – <endDate>)

## <Feature Area / Project 1>
- **[PR #123](url)**: <PR title> (<N> files changed) — <Completed|Active>
  - **Summary:** <extracted from PR description body>
  - **Impact:** <extracted from PR description body>
- **[#78901](url)**: <Work item title> (<Type>, <State>, <Area Path>)
  - <brief summary from description/comments if available>

## <Feature Area / Project 2>
- [Task title](todoist-url) (Todoist, <project name>)
- <Work log entry> — Impact: <annotation>

## Active This Week
- **[#78902](url)**: <Title> (<Type>, <State>) — updated <date>
  - <brief summary from description/comments if available>

## Stale (No Recent Updates)
> These items are assigned to you but have not been updated during this period.
- [#45001](url): <Title>
- [#45002](url): <Title>
```

#### Manager Format

```markdown
# Status Update — <weekLabel>

**Completed:**
- <Concise description> ([PR #123](url))
- <Concise description> ([#78901](url))

**In Progress:**
- <Concise description> ([#78902](url))

**Blocked / Needs Attention:**
- (if any)
```

#### Format Selection

- If `--format both` (default): produce both detailed and manager formats.
- If `--format detailed`: produce only the detailed format.
- If `--format manager`: produce only the manager format.

### 5. Archive

Write the report to `<statusRepoPath>/weekly-statuses/<startDate>_to_<endDate>.md`, creating directories as needed.

- When `--output` is `file` or `both`: write the file. When archiving with `--format both`, archive the **detailed** version.
- When `--output` is `console`: skip archiving entirely.

### 6. Output

- When `--output` is `console` or `both`: display the report(s) to the user. If `--format both`, display both detailed and manager formats (separated by a horizontal rule).
- When `--output` is `file`: confirm the archive file path but do not display the report.
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
