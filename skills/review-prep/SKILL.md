---
name: review-prep
description: Synthesize archived weekly statuses into impact-focused narratives for performance reviews
argument-hint: "[--period Q1-2026] [--from DATE --to DATE] [--theme THEME] [--format narrative]"
---

# Review Prep — Impact Narrative Generator

Synthesizes archived weekly status reports and work log impact annotations into structured, impact-focused narratives for performance reviews.

## Usage

```
/review-prep --period Q1-2026
/review-prep --from 2026-01-01 --to 2026-03-31
/review-prep --period H1-2026 --theme "Reliability & Quality"
/review-prep --period Q1-2026 --format narrative
```

## Parameters

- `--period` — Named period: `Q1-2026`, `Q2-2026`, `H1-2026`, `FY2026`, etc.
- `--from` / `--to` — Explicit date range (YYYY-MM-DD). Overrides `--period`.
- `--theme` — Focus on a specific impact theme (see themes below).
- `--format narrative` — Output flowing prose paragraphs instead of bulleted lists.

## Instructions

When this skill is invoked with `$ARGUMENTS`:

### 1. Load Configuration

Read `~/.claude/work-status-config.json`.

If missing, tell the user:

> Configuration file not found. Please create `~/.claude/work-status-config.json` with at minimum:
> ```json
> {
>   "statusRepoPath": "~/repos/my-status"
> }
> ```

Then stop.

### 2. Determine Date Range

Parse arguments to resolve a date range:

| Argument | Resolution |
|----------|-----------|
| `--period Q1-2026` | 2026-01-01 to 2026-03-31 |
| `--period Q2-2026` | 2026-04-01 to 2026-06-30 |
| `--period Q3-2026` | 2026-07-01 to 2026-09-30 |
| `--period Q4-2026` | 2026-10-01 to 2026-12-31 |
| `--period H1-2026` | 2026-01-01 to 2026-06-30 |
| `--period H2-2026` | 2026-07-01 to 2026-12-31 |
| `--period FY2026` | 2025-07-01 to 2026-06-30 (Microsoft fiscal year) |
| `--from` / `--to` | Use dates as given |

If neither is provided, default to the current quarter.

### 3. Gather Source Data

Read all files within the date range from:

1. **Weekly statuses**: `<statusRepoPath>/weekly-statuses/<YYYY>-W<WW>.md` — read every file whose week falls within the date range.
2. **Work logs**: `<statusRepoPath>/work-log/<YYYY>-W<WW>.md` — parse the markdown tables, paying special attention to entries that have impact annotations (non-`—` values in the Impact column).

### 4. Synthesize into Impact Themes

Organize all gathered work into these impact themes:

| Theme | What belongs here |
|-------|------------------|
| **Reliability & Quality** | Bug fixes, incident response, test improvements, monitoring, SLA work |
| **Feature Delivery** | New features, feature enhancements, shipped capabilities |
| **Team Enablement** | Code reviews, mentoring, documentation, onboarding help, tooling |
| **Technical Excellence** | Refactoring, performance improvements, tech debt reduction, architecture |
| **Cross-Team Collaboration** | Cross-team projects, dependencies unblocked, shared components |

If `--theme` is specified, only produce output for that theme.

For each theme, produce:

1. **Summary statement** — 1-2 sentences capturing the overall impact.
2. **Key accomplishments** — bulleted list of specific items with quantifiable impact where possible.
3. **Supporting evidence** — references to PRs, work items, or specific dates.

### 5. Identify Gaps

Scan work log entries that have `—` in the Impact column. List these under a **"Gaps to Fill"** section:

```markdown
## Gaps to Fill

The following entries have no impact annotation. Consider adding impact
descriptions using `/log <note> --impact "..."`:

- 2026-02-10: Reviewed PR #4521 for tenant isolation changes
- 2026-02-15: Attended architecture review meeting
```

### 6. Output

Format the final document:

```markdown
# Impact Summary — <period>

## Reliability & Quality
**Summary:** <1-2 sentence impact statement>
- Accomplishment 1 (PR #123, ADO #456)
- Accomplishment 2

## Feature Delivery
**Summary:** <1-2 sentence impact statement>
- Accomplishment 1

## Team Enablement
...

## Technical Excellence
...

## Cross-Team Collaboration
...

---

## Gaps to Fill
- <date>: <entry without impact>
```

If `--format narrative` is specified, replace bulleted lists with flowing paragraphs suitable for pasting into a review form.

### 7. Save

Write the output to `<statusRepoPath>/review-prep/<period>.md` (e.g., `Q1-2026.md`), creating directories as needed.

Confirm the file path to the user.

## Configuration Reference

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `statusRepoPath` | No | `~/.claude/work-status/` | Root directory for status data |
