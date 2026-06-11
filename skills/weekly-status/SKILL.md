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

When this skill is invoked with arguments:

### 1. Load Configuration

Read `~\.agents\work-status-config.json`.

If missing, tell the user:

> Configuration file not found. Please create `~\.agents\work-status-config.json`:
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

Parse the time range arguments. The three options are mutually exclusive:

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

#### 3a. ADO Pull Requests

For each repo in `defaultRepos`:

1. Use `mcp__ado__repo_list_pull_requests_by_repo_or_project` to list PRs directly. Make **two calls in parallel**:
   - **Completed PRs**: `status: "Completed"`, `top: 50`
   - **Active PRs**: `status: "Active"`, `top: 50`
   - Both with `project`: config `adoProject`, `repositoryId`: the repo name
2. **Client-side filter** the combined results:
   - **Author**: `createdBy.uniqueName` matches config `userEmail` (case-insensitive)
   - **Date range (completed)**: `closedDate` falls within startDate–endDate (inclusive)
   - **Date range (active)**: `creationDate` falls within startDate–endDate (inclusive)
3. For each matching PR, extract:
   - **Title**
   - **Status**: completed or active
   - **Number of files changed**
   - **Target branch**: include only if it differs from the repo's default branch (main/master)
   - **URL**: use `_links.web.href` from the tool response (the web UI link)
   - **Summary and Impact**: parse the PR description body to extract Summary, Key Changes, and Impact sections (following the `/ado-pr` template format)

> **Why direct PR listing instead of commit search?** The previous approach used `mcp__ado__repo_search_commits` with `searchText: userEmail`, which searches commit *comments* — not author metadata. Squash-merge commits use the PR title as their comment, causing most PRs to be silently missed.

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

### 4. Present Items and Propose Grouping

Before synthesizing the final report, present all collected data to the user for review.

#### Part A — Show all items with IDs

Display a flat list of all items from every source, using prefixed identifiers for easy reference:
- `P<n>` = PR (e.g., `P1`, `P2`)
- `A<n>` = ADO work item — active this week only (e.g., `A1`, `A2`)
- `T<n>` = Todoist completed task (e.g., `T1`, `T2`)
- `W<n>` = Work log entry (e.g., `W1`, `W2`)

Format:
```markdown
## Collected Items

**PRs:**
[P1] PR #5036714: [ENST] Fix IKeyVaultReader DI registration... — Completed
[P2] PR #5038063: [ENST] Fix Kiota HTTP handler DI registration... — Completed
[P3] PR #5045104: [ENST] Register Kiota serialization factories... — Completed
[P4] PR #5038062: [NSCS] Configure MEO certificate and auth settings... — Completed

**ADO Work Items (active this week):**
[A1] #7114889: Register in 1P app a trusted subject name... (Task, Active)
[A2] #7029123: Angel Seiji Morimoto Burgos - SCP (User Story, New)
[A3] #6950056: [PROD] Sev 3: Major alert email not sent... (Bug, Active)

**Todoist:**
[T1] Fix Missing IKeyVaultReader DI Registration in ENST (Notification Services Cloud)
[T2] Fix ServiceIdentitySettings.ManagedIdentityClientId... (Notification Services Cloud)
[T3] Create minor update requests in MEO... (On Call & Issues)

**Work Log:**
[W1] 2026-03-23: Cleaned up ADO items assigned to me
[W2] 2026-03-25: Created GEAR-CAP request for OneCert domain registrations...
[W3] 2026-03-27: Added new MOBR v2 pipeline for deploying SCP 1P...
```

#### Part B — Show proposed grouping

Propose feature-area groups by analyzing item titles, ADO area paths, Todoist project names, and work log content. Merge items that represent the same work across sources. Use the item IDs for reference:

```markdown
## Proposed Grouping

**Group 1 — ENST / Notification Services Cloud:**
  [P1]+[T1] (merged — same IKeyVaultReader DI fix)
  [P2]+[T2] (merged — same Kiota handler DI fix)
  [P3]

**Group 2 — 1P App / MEO Authentication:**
  [P4], [A1], [W2], [W3]

**Group 3 — On Call & Issues:**
  [A3], [T3]

**Ungrouped:**
  [W1] (standalone — ADO cleanup)

**Active This Week** (auto-section, not editable):
  [A1], [A2], [A3]

**Stale** (auto-section, not editable):
  (items with no recent updates)
```

#### Part C — Confirmation loop

Prompt the user:
> **Does this grouping look right?** You can:
> - **Confirm**: "looks good" / "ready" → proceed to final report
> - Move items: "move W1 to Group 1"
> - Merge items: "merge A1 with W2"
> - Split items: "split P1 and T1"
> - Rename groups: "rename Group 2 to 'MEO Certificate Setup'"
> - Add/remove groups

**If the user requests changes:**
1. Apply the requested changes
2. Re-display the **updated grouping** (Part B format, with changes reflected)
3. Ask for confirmation again

**Repeat this cycle** until the user explicitly confirms the grouping is ready (e.g., "looks good", "ready", "go ahead").

### 5. Synthesize Report

Only runs after the user confirms the grouping. Combine data using the **confirmed grouping**.

#### Grouping and Deduplication

- Use the confirmed groups from Step 4 as the feature-area sections
- For merged items (e.g., `[P1]+[T1]`), combine into a single entry — use the PR as the primary item and incorporate any additional context from the Todoist task or work log entry
- The **Active This Week** and **Stale** sections are auto-generated and not subject to user grouping

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

### 6. Archive

Write the report to `<statusRepoPath>/weekly-statuses/<startDate>_to_<endDate>.md`, creating directories as needed.

- When `--output` is `file` or `both`: write the file. When archiving with `--format both`, archive the **detailed** version.
- When `--output` is `console`: skip archiving entirely.

### 7. Output

- When `--output` is `console` or `both`: display the report(s) to the user. If `--format both`, display both detailed and manager formats (separated by a horizontal rule).
- When `--output` is `file`: confirm the archive file path but do not display the report.
- Prompt: **"Any items have notable impact worth capturing? You can use `/log <note> --impact \"...\"` to annotate them."**

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `userEmail` | Yes | — | Your email for filtering ADO PRs by author |
| `adoProject` | Yes | — | Azure DevOps project name |
| `adoTeam` | No | — | ADO team name (for sprint resolution) |
| `statusRepoPath` | No | `~\.agents\work-status\` | Root directory for status data |
| `defaultRepos` | Yes | — | List of ADO repo names to search |
| `todoistProject` | No | — | Todoist project name to filter tasks (recursive) |
| `todoistLabels` | No | — | Todoist label names to include |
