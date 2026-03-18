---
name: log
description: Append a timestamped work entry to the current week's log file
argument-hint: "<note> [--impact \"Impact description\"]"
---

# Work Log Entry

Appends a timestamped entry to the current week's work log file.

## Usage

```
/log Fixed the auth middleware bug in ReadServices --impact "Reduced P1 incidents by eliminating token expiry crashes"
/log Reviewed PR #4521 for tenant isolation changes
```

## Instructions

When this skill is invoked with `$ARGUMENTS`:

### 1. Load Configuration

Read the config file at `~/.claude/work-status-config.json`.

If the file does not exist, tell the user:

> Configuration file not found. Please create `~/.claude/work-status-config.json` with at minimum:
> ```json
> {
>   "statusRepoPath": "~/repos/my-status"
> }
> ```
> See the [config reference](#configuration-reference) below for all options.

Then stop.

### 2. Parse Arguments

Parse `$ARGUMENTS` for:
- **note** — all free text (everything that is not a recognized flag)
- **--impact "..."** — optional impact description (the quoted string after `--impact`)

### 3. Determine File Path

1. Resolve `statusRepoPath` from config (default: `~/.claude/work-status/` if not set).
2. Calculate the current ISO week number and year (e.g., `2026-W12`).
3. Calculate the week's date range (Monday–Sunday).
4. Target file: `<statusRepoPath>/work-log/<YYYY>-W<WW>.md`

### 4. Create or Append

**If the file does not exist**, create it with this template:

```markdown
# Work Log — <YYYY>-W<WW> (<Mon date> – <Sun date>)

| Date | Entry | Impact |
|------|-------|--------|
```

**Then** append a new row to the table:

```
| <YYYY-MM-DD> | <note> | <impact or —> |
```

- Use today's date for the Date column.
- If `--impact` was not provided, use `—` (em dash) in the Impact column.

### 5. Confirm

Print a confirmation message showing:
- The entry that was added
- The file path where it was saved
- The current number of entries for this week

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `statusRepoPath` | No | `~/.claude/work-status/` | Root directory for all status data files |
