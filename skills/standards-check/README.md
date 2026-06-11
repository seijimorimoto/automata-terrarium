# Standards Check

Repo-agnostic standards verifier. Discovers a repo's project instruction and standards files (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`, plus anything those link to and any extras you point at), extracts the rules they encode, runs them against the current diff, and emits findings as a JSON array.

Useful standalone for spot checks before opening a PR — and consumed by `/implement`'s verify phase, where it runs in parallel with other quality gates.

Discovery is **diff-scoped**: standards files are picked up by walking upward from each changed file's directory to the repo root. Each rule's scope is the directory containing its source standards file, which makes the skill behave correctly in monorepos with per-subproject standards. See [Discovery](#discovery) for details.

## Prerequisites

- **Git** — the skill calls `git diff`, `git log`, `git rev-parse`, `git symbolic-ref`.
- **bash** + **`jq`** (for the POSIX helper script `scripts/check-conventional-commits.sh`), or **PowerShell** (for the `.ps1` helper). Both helper variants ship with the skill. jq is used for safe JSON encoding of commit subjects (which can contain quotes and other special chars).

No CLI auth (no `gh`, no `az`) is required. The skill is purely local.

## Installation

```powershell
# Windows (PowerShell)

# Project-level
Copy-Item -Recurse skills\standards-check <your-project>\.claude\skills\

# User-level
Copy-Item -Recurse skills\standards-check ~\.claude\skills\
```

```sh
# Linux / macOS / Git Bash
cp -r skills/standards-check <your-project>/.claude/skills/   # project-level
cp -r skills/standards-check ~/.claude/skills/                # user-level
```

If you're using `bin/seiji-claude-sync`, just run it once and `/standards-check` lands at the user level along with every other skill.

## Permissions

- Git read commands (`git diff`, `git log`, `git rev-parse`) — covered by [`settings/base.json`](../../settings/base.json).
- Helper script execution — `bash` (POSIX) and `pwsh` (Windows) on the user's PATH; no extra permission entries needed.

## Usage

```bash
/standards-check                                   # diff against auto-detected default branch
/standards-check --target develop                  # diff against develop instead
/standards-check --include extras/style-guide.md   # add an extra standards source
/standards-check --include a.md,b.md               # multiple extras (comma-separated)
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--target` | No | `git symbolic-ref refs/remotes/origin/HEAD` (typically `main`); falls back to `main` | Target branch for the diff |
| `--include` | No | (none) | Comma-separated repo-relative paths to extra standards files |

A `.standards-check.sources` file at the repo root (one repo-relative path per line, `#` for comments) is always read in addition to `--include`. Both `--include` and `.standards-check.sources` are treated as **repo-wide** (scope = repo root).

## Discovery

The skill discovers standards files based on the paths in the diff, not the cwd:

1. Run `git diff <target>...HEAD --name-only` to get the list of changed files.
2. For each changed file, walk upward from its directory to the repo root. At each level, pick up `CLAUDE.md`, `AGENTS.md`, `.cursorrules` if they exist.
3. Always also include the repo-root copies plus `.github/copilot-instructions.md` (this last one is conventionally repo-root only).
4. Each discovered file's **scope** is the directory it lives in. Rules from `apps/web/AGENTS.md` apply only to changed files under `apps/web/`. Rules from repo-root project instructions apply to every changed file.
5. Linked files (markdown links from a discovered file to another file in the repo) inherit their parent's scope.
6. `--include` and `.standards-check.sources` entries are treated as scope = repo root.

If the diff is empty, the skill returns `[]` immediately. If standards files are found but no changed file falls inside any rule's scope, the skill also returns `[]`.

**Standards files added in the same diff** are picked up and applied. If a PR introduces new standards, that's exactly when you want them enforced.

### Single-project vs monorepo

In a single-project repo, walking upward from any changed file converges on the same root, so the discovered set is identical to what a "walk from cwd up to root" approach would produce. The diff-scoped approach only diverges from the cwd-up approach in monorepos with per-subproject standards files — and there it does the obviously-right thing (only the relevant subproject's rules apply to each file).

## Output

A single JSON array on stdout. Each object:

```json
{
  "tier": "hard_block | soft_block | report",
  "file": "path/to/file or null",
  "line": 42,
  "rule_quote": "exact rule text from the source",
  "source_file": "AGENTS.md",
  "confidence": "high | medium | low",
  "message": "short explanation of the violation"
}
```

No standards files found → `[]` and exit 0.

The skill never exits non-zero — orchestrators decide what to do with the findings.

### Tiering rules

| Rule type | Confidence | Tier |
|-----------|------------|------|
| Mechanical | high | `hard_block` |
| Mechanical | low/medium | `soft_block` |
| Judgment | any | `report` |

When in doubt, downgrade. False positives at this layer waste user time; the orchestrator can catch a missed issue, but a wrongly hard-blocked PR is disruptive.

## Pre-baked recognizers

The skill ships with deterministic checks for common patterns it detects in the standards files:

| Pattern in source | Recognizer |
|-------------------|------------|
| "Conventional Commits" mentioned | Run `scripts/check-conventional-commits` against `git log <target>..HEAD --no-merges --format='%H %s'` (merge commits are exempt) |
| Branch-naming regex/template like `u/{username}/{feature}` | Match the current branch (`git rev-parse --abbrev-ref HEAD`) |
| "Permission entries must be sorted alphabetically" | Validate sort order of every `permissions.allow|deny|ask` array in changed JSON files |

Rules outside these recognizers fall back to in-prompt inspection by the agent.

### Conventional Commits helper override

By default, the helper accepts these types:

```
feat fix docs refactor chore test style perf build ci revert
```

To use a different vocabulary, set `CC_TYPES`:

```sh
CC_TYPES="feat fix release" git log target..HEAD --format='%H %s' | scripts/check-conventional-commits.sh
```

```powershell
$env:CC_TYPES = 'feat fix release'
git log target..HEAD --format='%H %s' | & scripts/check-conventional-commits.ps1
```

## Extending the skill

To add a new mechanical recognizer:

1. Drop a helper script under `scripts/` (POSIX `.sh` + Windows `.ps1`). Stdin is the natural input shape (most checks operate on a list of identifiers — commits, files, lines).
2. Each helper should emit one JSON object per finding to stdout (no array wrapper). The skill collects them.
3. Add a row to the "Pre-baked recognizers" table in `SKILL.md` describing what triggers the recognizer.

The skill does not need to be re-installed — `SKILL.md` is read each invocation.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Returns `[]` even when a project instruction file exists | Confirm there's actually a diff vs `--target`: `git diff <target>...HEAD --name-only`. Discovery is driven by the changed paths, so an empty diff yields no findings. |
| Subproject `AGENTS.md` not picked up | Discovery walks upward from each changed file's directory. If no changed file lives under that subproject, its standards file isn't in scope and its rules don't apply. Add `--include path/to/AGENTS.md` to force-include it as repo-wide. |
| `--target` fails ("not a branch") | Pass an explicit ref: `--target origin/main` or `--target main`. Auto-detection assumes `origin/HEAD` is set. |
| Conventional Commits flagged but the type is valid | Set `CC_TYPES` to your repo's accepted types (see above) or extend the script. |
| Helper not executable on Linux | `chmod +x skills/standards-check/scripts/check-conventional-commits.sh` (the file ships executable in git but local copy/extract may strip the bit). |
