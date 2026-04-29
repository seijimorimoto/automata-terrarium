---
name: coverage-check
description: Detect the project's coverage tool, run diff coverage on the current branch, classify uncovered chunks, and emit JSON findings
argument-hint: "[--target BRANCH] [--coverage-threshold N]"
---

# Coverage Check

A repo-agnostic diff-coverage checker. Detects the project's coverage tool from project files, runs coverage scoped to the diff (not the whole project), classifies each uncovered chunk by kind, and emits findings as a JSON array.

Used standalone for spot checks before opening a PR — and consumed by `/implement`'s verify phase, where it's one of the parallel checks. The skill **does not write tests**; that's the orchestrator's responsibility.

## Usage

```
/coverage-check [--target BRANCH] [--coverage-threshold N]
```

## Parameters

- `--target BRANCH` — Target branch to diff against. Default: auto-detected from `git symbolic-ref refs/remotes/origin/HEAD --short` (then strip `origin/`); falls back to `main`.
- `--coverage-threshold N` — Diff-coverage threshold as a percentage (0–100). Below the threshold → `soft_block` per uncovered chunk; without a threshold → all findings are `report`. Priority: flag value → project config → none.

## Output

Returns a JSON array of finding objects to stdout. Each object describes one uncovered chunk:

```json
{
  "tier": "soft_block | report",
  "file": "path/to/file",
  "line_start": 42,
  "line_end": 58,
  "chunk_kind": "pure_logic | trivial | untestable | generated",
  "uncovered_lines": [44, 45, 47, 50],
  "message": "short explanation",
  "summary": {
    "diff_coverage_pct": 67.5,
    "threshold": 80,
    "gap_lines": 14
  }
}
```

`summary` is the same on every finding — it carries the project-level numbers so a downstream tool can read it from any one finding.

If no coverage tool can be detected, the skill returns `[]` and exits 0.

## Instructions

When invoked:

### 1. Resolve scope

- **Target branch.** `--target` if provided, else `git symbolic-ref refs/remotes/origin/HEAD --short` (strip `origin/`), else `main`.
- **Diff range.** `git diff <target>...HEAD --name-only` for the file list; per-file unified diff for line ranges added in this branch.

### 2. Detect coverage tool

Inspect project files (in priority order):

| Project file | Coverage tool | Run command (typical) |
|--------------|---------------|----------------------|
| `pyproject.toml` with `[tool.coverage]` or `[tool.pytest]`; `setup.cfg` with `[coverage:run]` | **pytest-cov** | `pytest --cov=. --cov-report=xml` |
| `package.json` with `"jest"` config or jest in deps | **Jest** | `jest --coverage --coverageReporters=lcov` |
| `package.json` with `"vitest"` in deps | **Vitest** | `vitest run --coverage` |
| `package.json` with `"c8"` in deps | **c8** | `c8 --reporter=lcov <test-cmd>` |
| `*.csproj` files in tree | **Coverlet** (via `dotnet test`) | `dotnet test --collect:"XPlat Code Coverage"` |
| `go.mod` | **`go test -cover`** | `go test -coverprofile=coverage.out ./...` |
| `Cargo.toml` with `cargo-tarpaulin` or `cargo-llvm-cov` config | **cargo-tarpaulin / cargo-llvm-cov** | `cargo tarpaulin --out Xml` or `cargo llvm-cov --lcov` |

If no tool is detected, the skill emits a single `report`-tier finding with `message` "no coverage tool detected for this project" and exits 0. The orchestrator may surface this so the user can either configure one or skip the check.

### 3. Resolve threshold

Priority:
1. `--coverage-threshold N` flag.
2. Project config (e.g., `pyproject.toml [tool.coverage.report] fail_under`, `package.json` `"coverageThreshold"`, `*.csproj` `<Threshold>` element). Use the tool's configured threshold for diff coverage if present.
3. No threshold → all findings are `tier: "report"`.

### 4. Run coverage

Execute the tool's run command, scoped where possible to the changed files. Convert the tool's output (lcov, cobertura XML, `go cover` text, etc.) into a uniform per-line covered/uncovered map.

### 5. Compute diff coverage

For each file in the diff:
- Take the set of lines added in this branch (`git diff <target>...HEAD -U0` or per-file unified diffs, lines starting with `+` excluding diff headers).
- Subtract any lines that the coverage map shows as covered.
- The remainder is the uncovered diff lines.

Group consecutive uncovered lines into chunks (allow gaps of up to 1 line within a chunk). Each chunk becomes one finding.

`summary.diff_coverage_pct` = `100 * (added_lines - uncovered_lines) / added_lines`. Round to one decimal.

### 6. Classify each chunk

Inspect the chunk's source lines and pick the most specific kind:

| Kind | Heuristic |
|------|-----------|
| `pure_logic` | Branches, conditions, loops, calculations, transformations. The "interesting" code that drives behavior. **Default** for ambiguous chunks. |
| `trivial` | Getters, setters, DTOs, constants, simple delegations, `__repr__` / `ToString` / `String()` implementations, plain data containers. |
| `untestable` | Defensive panics, unreachable error branches (e.g., `default: unreachable!()`), platform-specific shims that can't run in CI. |
| `generated` | Auto-generated code (codegen markers, `// Code generated by ... DO NOT EDIT.`, `# generated`). |

When unsure between two kinds, pick the more conservative one (i.e., prefer `pure_logic` over `trivial` — the orchestrator should err on the side of asking for tests).

### 7. Tier each chunk

| Threshold present | `diff_coverage_pct` < threshold | Per-chunk tier |
|-------------------|--------------------------------|----------------|
| Yes | Yes | `soft_block` |
| Yes | No | `report` |
| No | (n/a) | `report` |

### 8. Emit findings

Print one JSON array to stdout. No prose, no markdown fences. Every finding carries the same `summary` object (project-level snapshot).

If `summary.diff_coverage_pct` is at or above the threshold (or there's no threshold), still emit per-chunk findings so the orchestrator can present line-targeted info — but tier them all as `report`.

### 9. Exit semantics

- No coverage tool detected → `[]` (or one `report`-tier note, see above), exit 0.
- Coverage run fails → emit one `report`-tier finding with `message` describing the failure (stderr tail, exit code), exit 0.
- Never exit non-zero.

## Examples

```bash
/coverage-check                              # auto-detect target + tool, no threshold
/coverage-check --target develop             # diff against develop
/coverage-check --coverage-threshold 80      # 80% threshold; below -> soft_block per chunk
```

## Behavior notes

- The skill is **read-only with respect to source code** — it never modifies files. It does run the test suite, which can produce coverage artifacts (e.g., `coverage.xml`, `coverage.out`) — those are coverage tool side effects, not skill writes.
- `--coverage-threshold N` overrides any project-configured threshold for the duration of this invocation only.
- The skill does not write tests. Auto-fixing uncovered chunks is the orchestrator's job (e.g., `/implement`'s verify phase auto-writes tests for `pure_logic` and `trivial` chunks; proposes exclusion comments for `untestable`; adds exclusion markers for `generated`).
