---
name: standards-check
description: Discover a repo's standards files, extract rules, check the current diff against them, and emit findings as JSON
argument-hint: "[--target BRANCH] [--include PATH[,PATH...]]"
---

# Standards Check

A repo-agnostic standards verifier. Finds the repo's standards files (CLAUDE.md, AGENTS.md, .cursorrules, etc.), extracts the rules they encode, runs the rules against the current diff, and emits findings as a JSON array. Used standalone for spot checks or as one of the parallel verification steps in `/implement`.

## Usage

```
/standards-check [--target BRANCH] [--include PATH[,PATH...]]
```

## Parameters

- `--target BRANCH` — Target branch to diff against. Default: auto-detected from `git symbolic-ref refs/remotes/origin/HEAD --short` (then strip `origin/`); falls back to `main`.
- `--include PATH[,PATH...]` — Comma-separated list of additional standards files to include in discovery. Paths are relative to the repo root.

A repo can also list extra standards sources in a `.standards-check.sources` file at the repo root (one repo-relative path per line, `#` for comments). The skill always reads that file when present, in addition to any `--include` flag.

## Output

Returns a JSON array of finding objects to stdout. Each finding has the shape:

```json
{
  "tier": "hard_block | soft_block | report",
  "file": "path/to/file or null",
  "line": 42,
  "rule_quote": "exact rule text from source",
  "source_file": "CLAUDE.md",
  "confidence": "high | medium | low",
  "message": "short explanation of the violation"
}
```

If no standards files are found, the skill returns `[]` and exits cleanly — never errors.

## Instructions

When this skill is invoked:

### 1. Resolve scope

- **Target branch.** Use `--target` if provided; else `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`). Fall back to `main`.
- **Diff range.** `git diff <target>...HEAD` for code changes; `git log <target>..HEAD --format=%s` for commit subjects; `git log <target>..HEAD --format=%H %s` for full identification.

### 2. Discover standards files

Walk from the current working directory up to the repo root. Collect these files when they exist:

- `CLAUDE.md`
- `AGENTS.md`
- `.cursorrules`
- `.github/copilot-instructions.md`

Then expand discovery:

- **Linked files.** Parse each discovered file for markdown links of the form `[label](relative/path.md)`. If the link target points at another file inside the repo, add it to the standards set (recursive — but limit recursion depth to 3 to avoid runaway expansion).
- **`--include` flag.** Add every comma-separated path the user passed.
- **`.standards-check.sources`.** If a `.standards-check.sources` file exists at the repo root, read it; each non-empty, non-`#` line is a repo-relative path to add to the set.

If the resulting set is empty, return `[]` and stop.

### 3. Extract rules

For each standards file, read it carefully and enumerate the rules it states. For each rule, classify it:

- **Mechanical** — a deterministic check is possible (e.g., commit-message format, branch-name pattern, file naming, presence of a header, sort order in a JSON array).
- **Judgment** — interpretation required (e.g., "keep functions small", "prefer composition over inheritance", "don't add features beyond what the task requires").

Pre-baked recognizers for common patterns (apply automatically when the source mentions them):

- **Conventional Commits.** If the source explicitly mentions Conventional Commits or the `<type>(<scope>): <summary>` pattern, run the helper script `scripts/check-conventional-commits.sh` (or `.ps1`) against `git log <target>..HEAD --format=%H %s` to validate every commit subject. Each non-conforming commit is one finding.
- **Branch-naming pattern.** If the source specifies a regex or template (e.g., `u/{username}/{feature}`), extract the pattern and check the current branch name (`git rev-parse --abbrev-ref HEAD`) against it. Non-conforming → one finding.
- **Permission-list sort.** If the source says permission entries must be sorted alphabetically and any permission JSON file is in the diff, parse the file and verify the order. Out-of-order → one finding per array.

When a rule isn't covered by a recognizer, fall back to inspecting the diff manually and emit findings using best judgment.

### 4. Tier each finding

| Rule type | Confidence | Tier |
| --- | --- | --- |
| Mechanical | high | `hard_block` |
| Mechanical | low/medium | `soft_block` |
| Judgment | any | `report` |

A finding is mechanical+high-confidence only when the check is fully deterministic and a false positive is implausible (e.g., a commit subject that obviously fails the Conventional Commits regex). When in doubt, downgrade — `soft_block` and `report` are recoverable; a wrongly hard-blocked PR is disruptive.

### 5. Emit findings

Print one JSON array to stdout. No prose, no markdown fences. If invoked from a `verify-runner` subagent under `/implement`, the orchestrator parses this directly. Always include the exact rule text in `rule_quote`, copy-pasted from the source — the orchestrator surfaces it to the user when explaining a block.

If a finding can't be tied to a specific file/line (e.g., a commit-message violation), set `file` and `line` to null but keep `source_file` populated.

### 6. Exit semantics

- Standards files not found → `[]`, exit 0.
- Any other error (e.g., bad `--include` path) → empty `[]`, but write a `report`-tier finding with `message` describing the issue. Exit 0.
- Never exit non-zero. The orchestrator decides what to do with findings.

## Helper scripts

This skill ships with helpers under `scripts/` that the agent can invoke when running mechanical checks:

- `scripts/check-conventional-commits.sh` (POSIX) and `.ps1` (Windows) — read commit subjects on stdin (one `<sha> <subject>` per line) and emit one JSON finding per non-conforming commit. Both variants use the canonical Conventional Commits regex (`^(feat|fix|docs|refactor|chore|test|style|perf|build|ci|revert)(\([^)]+\))?!?: .+$`). The `<type>` whitelist matches the types listed in this repo's CLAUDE.md. Repos that allow extra types can either bypass the helper (run their own check from the SKILL prompt) or override the script's `TYPES` env var.

## Examples

Standalone usage:

```bash
/standards-check                                  # diff against auto-detected default branch
/standards-check --target develop                 # diff against develop
/standards-check --include extras/style-guide.md  # add an extra standards source
```

Inside `/implement`'s verify phase, the orchestrator spawns a `verify-runner` subagent that invokes this skill and parses the JSON array.

## Behavior notes

- The skill is **read-only** — never modifies files, commits, or branches. All output is to stdout.
- Discovery is **path-deterministic**: walking from cwd up to repo root means the same files are picked up regardless of where you invoke from inside the tree.
- Pre-baked recognizers can be extended by adding new helpers under `scripts/` and referencing them in the rule-extraction step above.
