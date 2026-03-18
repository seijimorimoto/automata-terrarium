---
name: ado-task
description: Create, update, and manage Azure DevOps work items
argument-hint: "<create|done|update|list> [args]"
---

# ADO Task Manager

Create, update, complete, and list Azure DevOps work items from the command line.

## Usage

```
/ado-task create Fix the auth token expiry bug --desc "Tokens expire silently causing 401s" --type Bug
/ado-task done 78901 Fixed by adding token refresh logic
/ado-task update 78901 Waiting on code review from team
/ado-task list
/ado-task list --all
```

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
>   "adoTeam": "Your Team"
> }
> ```

Then stop.

Required config keys for this skill: `adoProject`, `adoTeam`.

### 2. Parse Subcommand

Parse the first word of `$ARGUMENTS` as the subcommand. The rest is arguments to that subcommand.

---

### Subcommand: `create`

**Syntax:** `create <title> [--desc "description"] [--type Bug|Task|User Story]`

1. Parse the title (all text before any flags), `--desc` (optional description), and `--type` (default: `Task`).
2. Resolve the **current sprint iteration** using `mcp__ado__work_list_team_iterations` with:
   - `projectName`: config `adoProject`
   - `teamName`: config `adoTeam`
   - `timeframe`: `"current"`
3. Use `mcp__ado__wit_create_work_item` with:
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
2. Use `mcp__ado__wit_update_work_item` to set:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `state`: `"Done"` (or `"Closed"` — try `Done` first; if the work item type does not support `Done`, use `Closed`)
3. If notes were provided, also use `mcp__ado__wit_add_work_item_comment` with:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `text`: the notes
4. Confirm the state change and comment (if any).

---

### Subcommand: `update`

**Syntax:** `update <id> <notes>`

1. Parse the work item ID (first argument) and notes (remaining text, required).
2. Use `mcp__ado__wit_add_work_item_comment` with:
   - `id`: the parsed ID
   - `projectName`: config `adoProject`
   - `text`: the notes
3. Confirm the comment was added.

---

### Subcommand: `list`

**Syntax:** `list [--all]`

1. Use `mcp__ado__wit_my_work_items` with:
   - `projectName`: config `adoProject`
2. If `--all` is NOT specified, filter to items in the current iteration only:
   - Resolve current iteration via `mcp__ado__work_list_team_iterations` (same as `create` subcommand).
   - Filter results to match that iteration path.
3. Display results as a formatted table:

```
| ID    | Type | Title                        | State       | Iteration        |
|-------|------|------------------------------|-------------|------------------|
| 78901 | Bug  | Fix auth token expiry        | In Progress | Sprint 42        |
| 78902 | Task | Update API documentation     | New         | Sprint 42        |
```

If no items found, say: "No work items found for the current sprint." (or "No work items found." if `--all`).

---

### Error Handling

- If an unrecognized subcommand is given, show the usage examples above.
- If a required argument is missing (e.g., `done` without an ID), show the syntax for that subcommand.

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `userEmail` | No | — | Used for auto-assignment on `create` |
| `adoProject` | Yes | — | Azure DevOps project name |
| `adoTeam` | Yes | — | ADO team name (for sprint resolution) |
