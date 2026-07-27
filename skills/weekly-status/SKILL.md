---
name: weekly-status
description: Generate a weekly status report from ADO, Todoist, WorkIQ, and local work log
argument-hint: "[--week 2026-W12] [--date 2026-03-16] [--from DATE --to DATE] [--output console|file|both] [--format detailed|manager|both] [--ado-updates on|off] [--ado-update-mode skip|replace] [--no-confirm]"
---

# Weekly Status Report Generator

Generates a comprehensive weekly status report by aggregating data from Azure DevOps, Todoist, WorkIQ candidate insights, and local work log entries.

## Usage

```
/weekly-status
/weekly-status --week 2026-W12
/weekly-status --date 2026-03-16
/weekly-status --from 2026-03-16 --to 2026-03-22
/weekly-status --output console --format manager
/weekly-status --output file --format detailed
/weekly-status --ado-updates off
/weekly-status --ado-update-mode replace
/weekly-status --no-confirm --ado-updates on
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
- `--ado-updates` — Whether to prepare Feature-level ADO update comments. Values: `on`, `off` (default: `on`).
  - `on` — render ADO update previews after the local report is generated and ask before posting in interactive runs.
  - `off` — generate only the local report; do not render or post ADO update comments.
- `--ado-update-mode` — How to handle an existing generated ADO update for the same work item and date range. Values: `skip`, `replace` (default: `skip`).
  - `skip` — do not create a duplicate when a matching idempotency marker already exists.
  - `replace` — update the existing generated comment when supported, or delete and repost when both operations are supported.
- `--no-confirm` — Skip interactive grouping and posting prompts. ADO posting in non-interactive mode requires `--ado-updates on` to be explicitly present; a defaulted `--ado-updates on` is not enough.

The three time range options (`--week`, `--date`, `--from`/`--to`) are **mutually exclusive**. If none is specified, the current ISO week is used.

When parsing arguments, track whether `--ado-updates` was explicitly supplied. This distinguishes the convenient interactive default from intentional non-interactive posting.

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

1. Use the available Azure DevOps MCP equivalent of `repo_list_pull_requests_by_repo_or_project` to list PRs directly. Make **two calls in parallel**:
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

> **Why direct PR listing instead of commit search?** The previous approach used the available Azure DevOps MCP equivalent of `repo_search_commits` with `searchText: userEmail`, which searches commit *comments* — not author metadata. Squash-merge commits use the PR title as their comment, causing most PRs to be silently missed.

#### 3b. ADO Work Items

**Step 1 — Fetch item IDs, basic fields, and links:**

Use the available Azure DevOps MCP equivalent of `wit_my_work_items` to get work items assigned to the user. This returns IDs, titles, types, states, area paths, and `ChangedDate`.

For each item, note:
- **Title**, **Type**, **State**, **Area Path**
- **ChangedDate**
- **URL**: use `_links.html.href` from the tool response (the web UI link, **not** the `url` field which points to the REST API)

If the basic response does not include relationships, use the available Azure DevOps MCP equivalent of `wit_get_work_items_batch_by_ids` with relationship expansion in batches of **10 items at a time** to fetch:
- **Parent and child work item links**
- **Related work item links**
- **PR, commit, and artifact links**

Fetch basic fields for linked parent and child items that are not already in the assigned-item set. Use them to build hierarchy and context, but do not treat an unassigned linked item as the user's work unless another weekly signal supports it.

**Step 2 — Classify work item signals internally:**

Classify items for data-fetching and synthesis only. Do **not** create final report inventory sections from these labels.

- **Changed this week**: items whose `ChangedDate` falls within startDate–endDate (inclusive), have comments/discussion updates in the range, or have linked PR activity in the range.
- **Follow-up candidate**: non-terminal assigned items whose `ChangedDate` falls outside the report date range and have no week-bounded comments or linked PR activity.
- **Inactive terminal**: items in terminal/inactive states such as `Removed`, `Closed`, `Deleted`, `Done`, or `Completed`. Exclude these from follow-up/stale handling unless they changed during the report week and matter to the week's narrative.

Treat the exact state comparison as case-insensitive. If a team's workflow uses additional terminal states, apply the same rule only when the state clearly means no further action is expected.

**Step 3 — Fetch descriptions and comments for changed items:**

For items classified as **Changed this week**, use the available Azure DevOps MCP equivalent of `wit_get_work_items_batch_by_ids` to fetch `System.Description` in batches of **10 items at a time**. Also fetch comments or discussion threads with the available Azure DevOps MCP equivalent for work item comments.

When summarizing, emphasize week-bounded deltas:
- Comments added during the report range
- State, assignment, title, or description changes when available
- PRs, commits, and linked artifacts created, updated, or completed during the report range
- How this week's updates changed the outcome, risk, or next step

Ignore generated weekly-status comments as source evidence. Treat any ADO comment containing an idempotency marker that starts with `<!-- weekly-status:` as prior tool output; use those comments only for duplicate detection and replacement in Step 7.

Do not fetch large descriptions or comment histories for inactive terminal items unless they changed during the report range and are needed to explain the week's work.

> **Why batches of 10?** The `System.Description` field and comments can contain rich HTML that can be very large. Fetching too many items with descriptions and comments in a single call can exceed tool response token limits, causing failures or requiring workarounds like Python parsing scripts.

#### 3c. Local Work Log

Read the file `<statusRepoPath>/work-log/<startDate>_to_<endDate>.md` if it exists. Parse the markdown table rows into entries. Include the impact annotation inline if present.

#### 3d. Todoist Completed Tasks

1. Use the available Todoist MCP equivalent of `find-projects` to find the project named in config `todoistProject`.
2. **Recursively collect all descendant project IDs**: walk the project tree to find all children, grandchildren, etc. of the matched project.
3. For each project ID (parent + all descendants), use the available Todoist MCP equivalent of `find-completed-tasks` with:
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

#### 3e. WorkIQ Candidate Evidence

If the WorkIQ MCP server is available, use the available WorkIQ MCP equivalent of `ask` to gather week-bounded candidate evidence from Microsoft 365 sources such as email, Teams messages, meetings, and files. Do not add a configuration key for this source.

Ask for work-relevant activity during startDate–endDate that may not be captured in ADO, PRs, Todoist, or the local work log. Focus the query on:
- Decisions, approvals, and planning discussions
- Follow-ups or action items from email, Teams, or meetings
- Reviews, design discussions, and coordination work
- Files or meeting artifacts that changed the status or next step of a work stream

When the tool supports timezone input, pass the user's local IANA timezone. If WorkIQ is unavailable or fails, continue without it and mention the missing source in the review phase only if it materially affects confidence.

For each WorkIQ candidate, capture:
- **Synthesized outcome**: a short summary in your own words
- **Source type**: email, Teams, meeting, file, or mixed
- **Date or date range**
- **Likely related ADO work item, PR, Todoist task, or work-log entry** when there is a clear match
- **Confidence**: strong, possible, or weak

Treat WorkIQ output as ambient evidence. Do **not** copy raw email, Teams, or meeting text into the report or archive. Do not quote people unless the user explicitly approves it during review.

### 4. Present Items and Propose Grouping

Before synthesizing the final report, present all collected data to the user for review.

#### Part A — Show all items with IDs

Display a flat list of all items from every source, using prefixed identifiers for easy reference:
- `P<n>` = PR (e.g., `P1`, `P2`)
- `A<n>` = ADO work item with week-bounded activity or relevant hierarchy context (e.g., `A1`, `A2`)
- `T<n>` = Todoist completed task (e.g., `T1`, `T2`)
- `W<n>` = Work log entry (e.g., `W1`, `W2`)
- `I<n>` = WorkIQ candidate insight (e.g., `I1`, `I2`)

Format:
```markdown
## Collected Items

**PRs:**
[P1] PR #5036714: [ENST] Fix IKeyVaultReader DI registration... — Completed
[P2] PR #5038063: [ENST] Fix Kiota HTTP handler DI registration... — Completed
[P3] PR #5045104: [ENST] Register Kiota serialization factories... — Completed
[P4] PR #5038062: [NSCS] Configure MEO certificate and auth settings... — Completed

**ADO Work Items:**
[A1] #7114889: Register in 1P app a trusted subject name... (Task, Active)
[A2] #7029123: Angel Seiji Morimoto Burgos - SCP (User Story, New; parent of A1)
[A3] #6950056: [PROD] Sev 3: Major alert email not sent... (Bug, Active)

**Todoist:**
[T1] Fix Missing IKeyVaultReader DI Registration in ENST (Notification Services Cloud)
[T2] Fix ServiceIdentitySettings.ManagedIdentityClientId... (Notification Services Cloud)
[T3] Create minor update requests in MEO... (On Call & Issues)

**Work Log:**
[W1] 2026-03-23: Cleaned up ADO items assigned to me
[W2] 2026-03-25: Created GEAR-CAP request for OneCert domain registrations...
[W3] 2026-03-27: Added new MOBR v2 pipeline for deploying SCP 1P...

**WorkIQ Candidate Insights:**
[I1] Teams/meeting: Decision to validate serialization fix candidate next week (2026-03-19, possible match: A3)
[I2] Email: Follow-up requested for SCP 1P onboarding approval (2026-03-25, strong match: A2)
```

#### Part B — Show proposed grouping

Propose work-stream groups using the ADO work item hierarchy as the primary structure. Attach related PRs, commits, Todoist tasks, WorkIQ candidates, and work log entries under the most specific matching work item. If a PR, task, or WorkIQ candidate cannot be linked to an ADO item, group it by feature area as a fallback. Use the item IDs for reference:

```markdown
## Proposed Grouping

**Group 1 — [A2] SCP 1P App Onboarding:**
  [A2]
  └─ [A1]+[P4]+[W2]+[W3]+[I2] (linked work item, PR, work log, and WorkIQ evidence)

**Group 2 — ENST / Notification Services Cloud:**
  [P1]+[T1] (merged — same IKeyVaultReader DI fix)
  [P2]+[T2] (merged — same Kiota handler DI fix)
  [P3]

**Group 3 — On Call & Issues:**
  [A3], [T3], [I1]

**Ungrouped:**
  [W1] (standalone — ADO cleanup)
```

#### Part C — Confirmation loop

Prompt the user:
> **Does this grouping look right?** You can:
> - **Confirm**: "looks good" / "ready" → proceed to final report
> - Move items: "move W1 to Group 1"
> - Merge items: "merge A1 with W2"
> - Split items: "split P1 and T1"
> - Rename groups: "rename Group 2 to 'MEO Certificate Setup'"
> - Include or remove WorkIQ insights: "remove I1" / "include I2 in Group 1"
> - Add/remove groups

**If the user requests changes:**
1. Apply the requested changes
2. Re-display the **updated grouping** (Part B format, with changes reflected)
3. Ask for confirmation again

**Repeat this cycle** until the user explicitly confirms the grouping is ready (e.g., "looks good", "ready", "go ahead").

If `--no-confirm` is set, do not prompt. Use the proposed grouping as confirmed for report generation. This does not by itself authorize ADO update posting unless `--ado-updates on` was explicitly supplied.

### 5. Synthesize Report

Only runs after the user confirms the grouping. Combine data using the **confirmed grouping**.

#### Grouping and Deduplication

- Use the confirmed groups from Step 4 as the feature-area sections
- Prefer the ADO parent/child hierarchy as the report structure when a group contains ADO work items
- When a group contains a parent Feature/Epic and child User Stories/Tasks, render the parent as the top-level outcome bullet and nest related children under a **Child work:** sub-bullet. Do not list the parent and children as peer accomplishments.
- Put shared narrative on the parent item: common progress, cross-child evidence, overall impact, and next step. Use child bullets only for distinct week-bounded deltas that are specific to that child item.
- For merged items (e.g., `[P1]+[T1]`), combine into a single outcome entry — use the ADO work item as primary when present, otherwise use the PR, and incorporate supporting context from Todoist tasks, WorkIQ candidates, or work log entries
- Keep active/stale/follow-up labels internal. Do **not** add **Active This Week** or **Stale** inventory sections to the final report.
- When source signals conflict or are unclear, place the item in a concise **Needs Follow-up** entry only if it affects the coming week
- Include WorkIQ evidence only when the user keeps it in the confirmed grouping. Omit removed WorkIQ candidates entirely.

#### Evidence Model

Before writing the report, build a compact evidence model for each confirmed group:
- **Work stream / owning ADO item**: parent item, child items, state, and area path
- **Weekly deltas**: comments, state changes, description/title changes, PR updates, Todoist completions, WorkIQ candidates, and work log entries within startDate–endDate
- **Outcome**: the progress or decision implied by the deltas
- **Child work**: distinct week-bounded deltas per child item; omit or keep terse when the child only repeats the parent outcome
- **Evidence references**: ADO item links, PR links, Todoist links, WorkIQ candidate IDs, and work log IDs
- **Next step / risk**: only when the evidence supports one

Use the evidence model to write outcome-oriented bullets. Avoid repeating the same work across ADO, PR, Todoist, WorkIQ, and work-log sections.

#### Hyperlinked References

Use web UI URLs from tool responses — **never** use the `url` field for ADO items (it points to the REST API and renders as raw JSON):
- ADO Work Items: `**[#78901]({_links.html.href}) <title>**` — bold the linked ID and title together
- ADO PRs: `**[PR #123]({_links.web.href}) <title>**` — bold the linked PR ID and title together
- Todoist tasks: `[task title]({url})` — Todoist's `url` field is already a web link
- WorkIQ candidates: summarize as source type and date only unless the user explicitly approves a link or quotation during review

#### Detailed Format

```markdown
# Weekly Status — <weekLabel> (<startDate> – <endDate>)

## Highlights
- <Most important outcome or decision from the week> ([#78901](url), [PR #123](url))

## <ADO Work Stream / Feature Area 1>
- **[#78901](url) <Parent Feature title>** (<Type>, <State>, <Area Path>)
  - **Progress this week:** <shared week-bounded outcome from comments, description changes, PRs, Todoist, WorkIQ, and work log>
  - **Child work:**
    - **[#78902](url) <Child User Story title>**: <distinct week-bounded delta for this child>
    - **[#78903](url) <Child Task title>**: <distinct week-bounded delta for this child>
  - **Evidence:** **[PR #123](url) <PR title>**, [task title](todoist-url), WorkIQ Teams decision on <date>, W1
  - **Next:** <next step, only if clear from evidence>

## <Feature Area / Project 2>
- **[PR #456](url) <PR title>** (<N> files changed) — <Completed|Active>
  - **Progress this week:** <outcome summary from the PR and related tasks>
  - **Evidence:** [task title](todoist-url)

## Needs Follow-up
- <Only include unclear, blocked, or risk-bearing items that need attention next week; omit when none>
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

#### Final Review Pass

Before presenting or archiving the report, check:
- Every main claim is grounded in week-bounded evidence.
- Related ADO items, PRs, Todoist tasks, WorkIQ candidates, and work log entries are deduplicated into one outcome where possible.
- PR-only items have been linked back to ADO work items when relationships or titles support it.
- Parent and child ADO items are not flattened into peer bullets when a clear hierarchy exists.
- Shared narrative is not duplicated across parent and child items; children only carry distinct deltas.
- The full artifact identity is bolded together: linked ID plus title, not only the ID.
- Terminal inactive ADO states are not described as stale or pending follow-up unless they changed during the report week.
- The report does not contain raw **Active This Week** or **Stale** inventory sections.
- WorkIQ content is included only when confirmed in the review phase, and the archived report contains synthesized outcomes rather than raw email, Teams, or meeting text.
- Generated weekly-status ADO comments are excluded from the evidence model so the report does not summarize its own previous output.

### 6. Archive

Write the report to `<statusRepoPath>/weekly-statuses/<startDate>_to_<endDate>.md`, creating directories as needed.

- When `--output` is `file` or `both`: write the file. When archiving with `--format both`, archive the **detailed** version.
- When `--output` is `console`: skip archiving entirely.

### 7. ADO Feature Updates

Run this step after the local report is synthesized and archived.

#### Enablement and confirmation

- If `--ado-updates off`: skip this step entirely.
- If `--ado-updates on` (default) in an interactive run: render ADO update previews and ask before posting.
- If `--no-confirm` is set and `--ado-updates` was omitted/defaulted: do not render or post ADO updates. State that non-interactive ADO posting requires explicit `--ado-updates on`.
- If `--no-confirm --ado-updates on` is set: post without prompting, using `--ado-update-mode` for existing generated comments.

#### Target selection

Build ADO update comments from the same confirmed evidence model as the local report, but scope each comment to one parent Feature. If a group has no Feature parent and the confirmed grouping uses an Epic as the owning item, use that Epic. Skip groups that do not have a clear parent work item.

For each target parent:
- Include only child work with week-bounded evidence from the report range.
- Use child items as the progress bullets and put the shared narrative on the parent.
- Keep the comment concise and safe for ADO history; do not include raw WorkIQ, email, Teams, meeting, or Todoist content.
- Prefer synthesized outcomes over evidence inventory. Work item and PR IDs may be referenced when useful.

#### Comment template

Use this structure for every generated ADO update comment:

```markdown
<!-- weekly-status:<startDate>_to_<endDate>:<target-work-item-id> -->
## Weekly update (<startDate> to <endDate>)

**TL;DR:** <one-sentence feature-level progress summary>

**Progress this week:**
- **#<child-id> <child title>:** <week-bounded progress, summarized at outcome level>

**Why it matters:** <impact, decision unlocked, risk reduced, or clarity gained>

**Next:** <next step / owner / open decision; omit this section if nothing actionable is known>
```

Do not include an empty `Next` section.

#### Idempotency and posting

Before posting, fetch comments for each target parent work item and search for the exact marker `<!-- weekly-status:<startDate>_to_<endDate>:<target-work-item-id> -->`.

- `--ado-update-mode skip`:
  - If a matching marker exists, skip that parent and report it as skipped.
  - If no matching marker exists, create a new comment with the available ADO work item comment write tool.
- `--ado-update-mode replace`:
  - If one matching marker exists, update that generated comment when the available ADO tool supports edits.
  - If edit is unavailable but delete and create are both supported, delete the existing generated comment and post the new body.
  - If replacement is unsupported, skip that parent and report the unsupported replacement rather than creating a duplicate.
  - If no matching marker exists, create a new comment.
- If multiple matching generated comments exist on the same parent, do not post automatically. In interactive mode, ask the user how to proceed. In `--no-confirm` mode, skip that parent and report the conflict.

In interactive mode, display each target parent, the planned action (`create`, `replace`, or `skip`), and the full comment body before asking:

> **Post these ADO updates?**

If the user declines, do not post any ADO updates; the local report remains generated and archived.

### 8. Output

- When `--output` is `console` or `both`: display the report(s) to the user. If `--format both`, display both detailed and manager formats (separated by a horizontal rule).
- When `--output` is `file`: confirm the archive file path but do not display the report.
- When ADO updates are enabled interactively, display ADO update previews separately from the local report, even when `--output file` suppresses report display.
- After ADO posting, summarize created, replaced, skipped, and conflicted parent work item IDs.
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
