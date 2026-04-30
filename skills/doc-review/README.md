# Doc Review

Repo-agnostic documentation checker. Inspects the current diff for documentation gaps — stale references, missing doc-comments, suggestions for new docs, broken index links — and emits findings as JSON. **Report-only**: never blocks anything; just surfaces what the orchestrator (or human reviewer) might want to act on.

Useful standalone before opening a PR, and consumed by `/implement`'s verify phase as one of the parallel checks.

## Prerequisites

- **Git** — the skill calls `git diff`, `git symbolic-ref`.

No CLI auth required. The skill is purely local. v1 has no helper scripts — inspections are run in-prompt by the agent.

## Installation

```powershell
# Windows (PowerShell)

# Project-level
Copy-Item -Recurse skills\doc-review <your-project>\.claude\skills\

# User-level
Copy-Item -Recurse skills\doc-review ~\.claude\skills\
```

```sh
# Linux / macOS / Git Bash
cp -r skills/doc-review <your-project>/.claude/skills/   # project-level
cp -r skills/doc-review ~/.claude/skills/                # user-level
```

If you're using `bin/seiji-claude-sync`, it lands at the user level along with every other skill.

## Permissions

Git read commands (`git diff`, `git symbolic-ref`) are covered by [`settings\base.json`](../../settings/base.json). No additional permissions needed.

## Usage

```bash
/doc-review                    # diff against auto-detected default branch
/doc-review --target develop   # diff against develop instead
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--target` | No | Auto-detected default branch (typically `main`) | Target branch for the diff |

## Doc-surface discovery

Before running the checks, the skill builds a **doc surface** — the set of doc files to inspect. It's the union of:

- A **global net**: top-level `*.md`, `docs/**/*.md` rooted at the repo root, and `CHANGELOG*` at the repo root.
- A **per-changed-file upward walk**: from each changed file's directory up to the repo root, picking up `README*`, a sibling `docs/**/*.md`, and `CHANGELOG*` at every ancestor. This is what catches per-package docs in monorepos (e.g., `packages\api\docs\architecture.md` when the change is under `packages\api\`).
- **Markdown-link expansion**: from any discovered doc, follow in-repo markdown links (`[label](relative/path.md)`) up to depth 3.

The doc surface is the input to checks 1 and 2 below. Discovery is symmetric to `/standards-check`'s diff-scoped walk, but doc files aren't directory-scoped, so the global net is kept in addition to the per-file walk.

## What it checks

1. **Accuracy of existing docs against current code.** Function signatures referenced in docs match current code; code examples match the current API; behavioral descriptions still align; config keys/flags described in docs match what the code reads.
2. **Stale references.** Doc files reference identifiers, flag names, file paths, or commands that were renamed or removed in the diff.
3. **Missing doc comments on new exported symbols.** Per-language hooks: `.py` → docstring; `.ts/.js/.tsx/.jsx` → JSDoc; `.go` → doc comment on exported identifier; `.cs` → XML doc; `.rs` → `///`. Plus: new config options/flags not documented; new CLI commands or public APIs not reflected in user-facing docs.
4. **Suggest new documentation.** Substantial new module/directory → suggest README. New architectural concept → suggest doc page. Significant behavioral change with a CHANGELOG-style file present → suggest CHANGELOG entry. New CLI command or public API → suggest user-facing doc updates.
5. **Index linkage.** New top-level files in `docs/`-like directories aren't linked from any index file.

## Output

A single JSON array on stdout. Each object:

```json
{
  "tier": "report",
  "file": "path/to/file or null",
  "line": 42,
  "rule_quote": "concise description of the gap",
  "source_file": "doc-review",
  "confidence": "high | medium | low",
  "message": "explanation; for suggestion-style findings, includes the suggested action"
}
```

Empty diff → `[]` and exit 0. The skill never exits non-zero.

### Confidence calibration

- `high` — mechanically detectable (signature mismatch, rename trail, missing doc comment on exported symbol).
- `medium` — heuristic but clear (suggesting README on a new substantial module).
- `low` — reasonable suggestion that may or may not apply.

## Behavior notes

- **Report-only.** Even findings tagged `confidence: high` use `tier: "report"`. The skill never hard-blocks — surfacing is its only job.
- **Read-only.** Never modifies files, commits, or branches.
- **In-prompt v1.** No helper scripts ship with this skill. Future extensions (e.g., a deterministic Go exported-symbol scanner) drop a script under `scripts/` and a reference in `SKILL.md`.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Returns `[]` even when there are obvious doc gaps | Confirm there's actually a diff vs the target branch (`git diff --stat <target>...HEAD`). The skill operates on the diff, not the whole repo. |
| `--target` fails ("not a branch") | Pass an explicit ref: `--target origin/main` or `--target main`. Auto-detection assumes `origin/HEAD` is set. |
| Findings reference identifiers that aren't actually missing | The accuracy/stale-reference checks rely on string matching; rare false positives can occur. Verify before acting. |
