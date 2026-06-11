---
name: ado-task
description: Create, update, and manage Azure DevOps work items
argument-hint: "<create|done|update|bulk|list> [args]"
---

# ADO Task Manager

Create, update, complete, and list Azure DevOps work items from the command line.

## Usage

```
/ado-task create Fix the auth token expiry bug --desc "Tokens expire silently causing 401s" --type Bug
/ado-task done 78901 Fixed by adding token refresh logic
/ado-task update 78901 Waiting on code review from team
/ado-task update 78901 --state Active
/ado-task update 78901 --state "In Progress" Started working on this
/ado-task bulk 78901,78902,78903 --state "Cut" "Won't do these items"
/ado-task bulk 78901,78902 --state Closed
/ado-task list
/ado-task list --all
/ado-task list --filter "state=Active"
/ado-task list --filter "type=Bug state=Active,New"
/ado-task list --order-by "updated desc"
/ado-task list --all --order-by "state asc, id desc"
```

## Instructions

When this skill is invoked:

### 1. Load Configuration

Read `~\.agents\work-status-config.json`.

If missing, tell the user:

> Configuration file not found. Please create `~\.agents\work-status-config.json`:
> ```json
> {
>   "userEmail": "you@example.com",
>   "adoProject": "Your Project",
>   "adoTeam": "Your Team"
> }
> ```

Then stop.

Required config keys for this skill: `adoProject`, `adoTeam`.

### 2. Parse Subcommand

Parse the first word of the skill arguments as the subcommand. The rest is arguments to that subcommand.

---

### Subcommand: `create`

**Syntax:** `create <title> [--desc "description"] [--type Bug|Task|User Story]`

1. Parse the title (all text before any flags), `--desc` (optional description), and `--type` (default: `Task`).
2. Resolve the **current sprint iteration** using the available Azure DevOps MCP equivalent of `work_list_team_iterations` with:
   - `projectName`: config `adoProject`
   - `teamName`: config `adoTeam`
   - `timeframe`: `"current"`
3. Use the available Azure DevOps MCP equivalent of `wit_create_work_item` with:
   - `projectName`: config `adoProject`
   - `workItemType`: the parsed type (default `Task`)
   - `title`: the parsed title
   - `description`: the parsed description (if provided)
   - `iterationPath`: the iteration path from step 2
   - `assignedTo`: config `userEmail`
4. Display the created work item ID, title, and URL.

---

### Subcommand: `done`

**Syntax:** `done <id> [notes]`

1. Parse the work item ID (first argument) and optional notes (remaining text).
2. Use the available Azure DevOps MCP equivalent of `wit_update_work_item` to set:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `state`: `"Closed"` (or `"Done"` — try `Closed` first; if the work item type does not support `Closed`, use `Done`)
3. If notes were provided, also use the available Azure DevOps MCP equivalent of `wit_add_work_item_comment` with:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `text`: the notes
4. Confirm the state change and comment (if any).

---

### Subcommand: `update`

**Syntax:** `update <id> [--state "<state>"] [notes]`

At least one of `--state` or notes must be provided.

1. Parse the work item ID (first argument), optional `--state` flag, and optional notes (remaining text after flags).
2. If `--state` is provided, use the available Azure DevOps MCP equivalent of `wit_update_work_item` to set:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `state`: the parsed state value
   - Supported states (case-insensitive): `Accepted`, `Active`, `Blocked`, `Cancelled`, `Closed`, `Committed`, `Completed`, `Cut`, `Deferred`, `Design`, `In Planning`, `In Progress`, `Inactive`, `New`, `Proposed`, `Ready`, `Removed`, `Requested`, `Resolved`.
   - If the state is not supported by the work item type, report the error to the user.
3. If notes were provided, use the available Azure DevOps MCP equivalent of `wit_add_work_item_comment` with:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `text`: the notes
4. Confirm the state change (if any) and comment (if any).

---

### Subcommand: `bulk`

**Syntax:** `bulk <id1,id2,...> [--state "<state>"] [notes]`

At least one of `--state` or notes must be provided. IDs are comma-separated.

1. Parse the comma-separated work item IDs, optional `--state` flag, and optional notes (remaining text after flags).
2. If `--state` is provided, use the available Azure DevOps MCP equivalent of `wit_update_work_items_batch` with a single batch call containing one update per ID:
   - Each update: `{ "op": "Replace", "id": <id>, "path": "/fields/System.State", "value": "<state>" }`
   - Supported states (case-insensitive): `Accepted`, `Active`, `Blocked`, `Cancelled`, `Closed`, `Committed`, `Completed`, `Cut`, `Deferred`, `Design`, `In Planning`, `In Progress`, `Inactive`, `New`, `Proposed`, `Ready`, `Removed`, `Requested`, `Resolved`.
   - If the batch update fails (e.g., some work item types don't support the requested state), report which items failed and suggest a fallback state (e.g., "Closed" instead of "Cut" for Bugs).
3. If notes were provided, call the available Azure DevOps MCP equivalent of `wit_add_work_item_comment` for **each** ID individually with:
   - `projectName`: config `adoProject`
   - `workItemId`: the ID
   - `comment`: the notes
4. Display a summary table of results:

```
| ID    | State Change | Comment | Error |
|-------|-------------|---------|-------|
| 78901 | New → Cut   | Added   |       |
| 78902 | New → Cut   | Added   |       |
| 78903 | New → ✗     |         | "Cut" not supported for Bug; try "Closed" |
```

---

### Subcommand: `list`

**Syntax:** `list [--all] [--filter "<field>=<value>[,<value>...] [...]"] [--order-by "<field> <direction>[, ...]"]`

1. Use the available Azure DevOps MCP equivalent of `wit_my_work_items` with:
   - `projectName`: config `adoProject`
2. Extract the IDs from the results and fetch full details using the available Azure DevOps MCP equivalent of `wit_get_work_items_batch_by_ids` with:
   - `projectName`: config `adoProject`
   - `ids`: the list of work item IDs from step 1
   - `fields`: `["System.Id", "System.WorkItemType", "System.Title", "System.State", "System.IterationPath", "System.CreatedDate", "System.ChangedDate"]`
3. **Filter the results:**
   - **Default (no `--all`, no `--filter`):** Exclude items with state in: `Closed`, `Resolved`, `Removed`, `Cut`.
   - **`--all`:** No filtering — show all items regardless of state.
   - **`--filter`:** Apply custom client-side filtering. When `--filter` is provided, the default state exclusion is NOT applied. Parse the value as space-separated `<field>=<value>[,<value>...]` pairs.
     - Supported fields (case-insensitive): `state`, `type`, `iteration`.
     - Multiple values for the **same** field are OR'd (e.g., `state=Active,New` matches Active OR New).
     - Different fields are AND'd (e.g., `type=Bug state=Active,New` matches Bugs that are Active or New).
     - Field-to-ADO mapping: `state` → `System.State`, `type` → `System.WorkItemType`, `iteration` → `System.IterationPath` (partial match — matches if the iteration path contains the value).
4. **Sort the results:**
   - **Default sort (no `--order-by`):** sort by ID ascending.
   - **With `--order-by`:** parse the value as a comma-separated list of `<field> <direction>` pairs and sort accordingly (first pair is primary sort key, second is secondary, etc.).
   - Supported field names (case-insensitive): `id`, `type`, `title`, `state`, `iteration`, `created`, `updated`.
   - Supported directions: `asc` (default if omitted), `desc`.
   - Example: `--order-by "state asc, id desc"` sorts by state ascending first, then by ID descending within each state.
5. Display results as a formatted table with dates formatted as `YYYY-MM-DD HH:MM`:

```
| ID    | Type | Title                    | State       | Iteration  | Created          | Updated          |
|-------|------|--------------------------|-------------|------------|------------------|------------------|
| 78901 | Bug  | Fix auth token expiry    | In Progress | Sprint 42  | 2025-01-15 09:30 | 2025-03-20 14:12 |
| 78902 | Task | Update API documentation | New         | Sprint 42  | 2025-02-01 11:00 | 2025-03-18 08:45 |
```

If no items found, say: "No work items found matching the current filter." (or "No work items found." if `--all`).

---

### Error Handling

- If an unrecognized subcommand is given, show the usage examples above.
- If a required argument is missing (e.g., `done` without an ID, `bulk` without IDs), show the syntax for that subcommand.
- If an Azure DevOps MCP tool is unavailable, say which Azure DevOps capability is missing and suggest running `/mcp` to configure the ADO server.
- Do not silently ignore failed work item updates; report the item ID and error.

## MCP Tool Notes

- MCP tool names vary by runtime and server. Use the available Azure DevOps MCP equivalent for each named capability.

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `userEmail` | No | — | Used for auto-assignment on `create` |
| `adoProject` | Yes | — | Azure DevOps project name |
| `adoTeam` | Yes | — | ADO team name (for sprint resolution) |
