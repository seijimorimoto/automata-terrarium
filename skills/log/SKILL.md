---
name: log
description: Append a timestamped work entry to the current week's log file
argument-hint: "<note> [--impact \"Impact description\"] [--week 2026-W12] [--date 2026-03-16]"
---

# Work Log Entry

Appends a timestamped entry to the current week's work log file.

## Usage

```
/log Fixed the auth middleware bug in ReadServices --impact "Reduced P1 incidents by eliminating token expiry crashes"
/log Reviewed PR #4521 for tenant isolation changes
/log Backfill entry from last week --week 2026-W11
/log Completed design doc --date 2026-03-10 --impact "Unblocked frontend team"
```

## Instructions

When this skill is invoked with arguments:

### 1. Load Configuration

Read the config file at `~\.agents\work-status-config.json`.

If the file does not exist, silently use defaults (`statusRepoPath` = `~\.agents\work-status\`). Do **not** block or prompt the user.

### 2. Parse Arguments

Parse the skill arguments for:
- **note** — all free text (everything that is not a recognized flag or its value)
- **--impact "..."** — optional impact description (the quoted string after `--impact`)
- **--week YYYY-WNN** — optional; target the ISO week specified (e.g., `2026-W11`). Resolve to Monday–Sunday of that week.
- **--date YYYY-MM-DD** — optional; target the ISO week that contains the given date.

`--week` and `--date` are **mutually exclusive**. If both are provided, tell the user to pick one and stop.

Default (no time flag): current ISO week.

### 3. Determine File Path

1. Resolve `statusRepoPath` from config (default: `~\.agents\work-status\` if not set).
2. Using the resolved week (from Step 2), calculate:
   - The ISO week number and year (e.g., `2026-W12`).
   - The week's start date (Monday) and end date (Sunday) in `YYYY-MM-DD` format.
3. Target file: `<statusRepoPath>/work-log/<startDate>_to_<endDate>.md`
   (e.g., `~\.agents\work-status\work-log\2026-03-16_to_2026-03-22.md`)

### 4. Create or Append

**If the file does not exist**, create it with this template:

```markdown
# Work Log — <YYYY>-W<WW> (<startDate> – <endDate>)

| Date | Entry | Impact |
|------|-------|--------|
```

**Then** append a new row to the table:

```
| <date> | <note> | <impact or —> |
```

The Date column value:
- Default (no time flag): today's date (`YYYY-MM-DD`)
- If `--date` was provided: use that date
- If `--week` was provided: use today's date (the flag only controls which file to target)

If `--impact` was not provided, use `—` (em dash) in the Impact column.

### 5. Confirm

Print a confirmation message showing:
- The entry that was added
- The file path where it was saved
- The current number of entries for this week

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `statusRepoPath` | No | `~\.agents\work-status\` | Root directory for all status data files |
