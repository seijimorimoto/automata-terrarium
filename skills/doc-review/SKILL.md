---
name: doc-review
description: Check the current diff for missing or stale documentation and emit report-only findings as JSON
argument-hint: "[--target BRANCH]"
---

# Doc Review

A repo-agnostic documentation checker. Inspects the current diff for documentation gaps — stale references, missing doc-comments, suggestions for new docs — and emits findings as a JSON array.

All findings are `tier: "report"`. The skill never blocks; it surfaces ideas the orchestrator (or the human) can act on.

## Usage

```
/doc-review [--target BRANCH]
```

## Parameters

- `--target BRANCH` — Target branch to diff against. Default: auto-detected from `git symbolic-ref refs/remotes/origin/HEAD --short` (then strip `origin/`); falls back to `main`.

## Output

Returns a JSON array of finding objects to stdout, same shape as `/standards-check`:

```json
{
  "tier": "report",
  "file": "path/to/file or null",
  "line": 42,
  "rule_quote": "concise description of the gap",
  "source_file": "doc-review",
  "confidence": "high | medium | low",
  "message": "explanation; for suggestion-style findings, include the suggested action"
}
```

If the diff is empty (no changes vs target), the skill returns `[]` and exits 0.

## Instructions

When invoked:

### 1. Resolve scope

- Target branch as in `/standards-check`: `--target` if provided, else `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`), else `main`.
- Diff: `git diff <target>...HEAD` for code; `git diff <target>...HEAD --name-status` for renamed/deleted file detection.

### 2. Discover doc surface (diff-scoped)

Documentation isn't directory-scoped the way standards-rule files are — a doc at the repo root can describe code anywhere — so the doc surface is the **union** of a global net and a per-changed-file walk:

1. **Global net** (catches docs that live away from the code they describe):
   - Top-level `*.md` (e.g., `README.md`, `CONTRIBUTING.md`)
   - `docs/**/*.md` rooted at the repo root
   - `CHANGELOG*` at the repo root
2. **Upward walk** from each changed file's directory to the repo root (catches per-package docs in monorepos). At **every** ancestor directory, collect the same kinds of doc surfaces — not just READMEs:
   - `README*` in that directory
   - `docs/**/*.md` rooted at that directory (i.e., a sibling `docs/` folder and everything beneath it)
   - `CHANGELOG*` in that directory
3. **Markdown-link expansion.** From every doc file collected so far, parse markdown links of the form `[label](relative/path.md)` (or `.mdx`). If the link target points at another file inside the repo, add it to the doc set. Recurse to a maximum depth of 3 to avoid runaway expansion.

Deduplicate by repo-relative path. The resulting set is the **doc surface** used by checks A and B below.

### 3. Run the checks

Run each of these inspections against the diff. Each can produce zero or more findings.

#### A. Accuracy of existing docs against current code

For each doc file in the doc surface that mentions code that changed in this diff:

- **Function signatures** referenced in docs match the current code.
- **Code examples** in docs match the current API (parameter names, return types, expected output).
- **Behavioral descriptions** still align with the new implementation (e.g., docs say "returns null on missing key" but code now throws).
- **Config keys / flags** described in docs match what the code reads.

For each mismatch, emit a finding pointing at the doc file (and line if pinpointable), with `message` describing the divergence and the corrected text.

#### B. Stale references

For each rename or delete in the diff (`git diff --name-status`, plus identifier-level renames detected from the patch):

- Search the doc surface for the old name. Each occurrence is a finding pointing at the doc file/line, with `message` "renamed to `<new name>`" or "removed".

#### C. Missing doc comments on new exported symbols

For each newly added exported symbol in the diff, check for an adjacent doc-comment using per-language conventions:

| Extension | Doc-comment style |
|-----------|-------------------|
| `.py` | docstring (`"""..."""` or `'''...'''`) |
| `.ts`, `.tsx`, `.js`, `.jsx` | JSDoc (`/** ... */`) |
| `.go` | doc comment on the exported identifier |
| `.cs` | XML doc (`/// <summary>...`) |
| `.rs` | `///` doc comments |
| (other) | any adjacent comment block immediately above |

If the symbol is exported and has no adjacent doc comment, emit a finding pointing at the symbol's file/line, `message` "new exported symbol `<name>` lacks a doc comment".

Also check:
- **New configuration options / flags** added in code that aren't documented in the user-facing config docs (e.g., the repo's README or a `docs/configuration.md`).
- **New CLI commands or public APIs** that aren't reflected in user-facing docs.

#### D. Suggest new documentation

Heuristics — emit a finding only when the trigger is clearly met:

- **New module/directory with substantial code** (e.g., > ~100 lines net add, > 1 file) and no `README.md` inside it → suggest adding a README. Set `confidence` based on size (large addition = `high`).
- **New top-level architectural concept** (e.g., a new top-level package, a service, a kind of object) → suggest a doc page describing it.
- **Significant behavioral change** (renames in the public surface, breaking changes, new defaults) AND the repo has a `CHANGELOG*` file → suggest a CHANGELOG entry.
- **New CLI command or public API** → suggest user-facing doc updates.

For each, include the suggested action in `message` (e.g., "Add `skills/standards-check/README.md` covering Prerequisites, Installation, Usage, Output").

#### E. Index linkage

If the diff adds new files in a `docs/`-like directory (any directory where the existing files are mostly markdown and there's an `index.md` / `README.md` / `SUMMARY.md` listing them), and those new files aren't linked from the index file:

- Emit a finding pointing at the index, `message` "new file `<path>` not linked from this index".

### 4. Confidence calibration

- **`high`** — mechanically detectable (function signature mismatch, identifier rename trail, missing doc comment on exported symbol). Use sparingly — when the gap is unambiguous.
- **`medium`** — heuristic but clear (suggesting README on a new substantial module).
- **`low`** — reasonable suggestion that may or may not apply (suggesting CHANGELOG when the repo's CHANGELOG style is unclear).

### 5. Emit findings

Print one JSON array to stdout. No prose, no markdown fences. All findings have `tier: "report"`. Even when the gap looks mechanical, the skill never hard-blocks — its role is to surface, not gate.

If invoked from a `verify-runner` subagent under `/implement`, the orchestrator parses this directly and may choose to post line-targeted PR comments for these findings.

### 6. Exit semantics

- Empty diff → `[]`, exit 0.
- Any internal error → emit a `report`-tier finding with `message` describing the issue, exit 0.
- Never exit non-zero.

## Examples

```bash
/doc-review                    # diff against auto-detected default branch
/doc-review --target develop   # diff against develop instead
```

## Behavior notes

- The skill is **read-only** — never modifies files, commits, or branches. All output is to stdout.
- **Doc-surface discovery** combines a global net (top-level `*.md`, root `docs/**/*.md`, root `CHANGELOG*`) with an upward walk from each changed file's directory, applying the same `README* / docs/**/*.md / CHANGELOG*` patterns at every ancestor. Markdown links inside any discovered doc are followed up to depth 3. The split mirrors `/standards-check`'s diff-scoped walk, but doc files aren't directory-scoped — a root `docs/api.md` may describe code anywhere — so the global net stays in addition to, not replaced by, the per-file walk.
- v1 has no helper scripts — the inspections are done in-prompt by the agent. Per-language doc-comment recognizers ship as natural-language rules in the per-extension table above; if a future extension warrants a deterministic check (e.g., a Go-specific exported-symbol scanner), drop a script under a `scripts/` folder and reference it here.
- Suggestions are advisory. The orchestrator decides whether to surface them as PR comments, ignore them, or auto-apply trivial cases (e.g., adding a placeholder docstring).
