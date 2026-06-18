# Coverage Check

Repo-agnostic diff-coverage checker. Detects the project's coverage tool from project files, runs coverage scoped to the diff, classifies each uncovered chunk by kind, and emits findings as JSON.

Used standalone for spot checks before opening a PR — and consumed by `/implement`'s verify phase as one of the parallel checks. The skill **does not write tests**; it only reports gaps.

## Prerequisites

- **Git** — calls `git diff`, `git symbolic-ref`.
- **A supported coverage tool installed and runnable** for the project at hand. The skill auto-detects which one. Supported toolchains:

| Project type | Tool | Install |
|--------------|------|---------|
| Python | `pytest-cov` | `pip install pytest pytest-cov` |
| TypeScript / JavaScript | `jest` (with built-in coverage), `vitest`, or `c8` | `npm install -D jest @types/jest` (etc.) |
| .NET | Coverlet (bundled with `Microsoft.NET.Test.Sdk`) | `dotnet add package coverlet.collector` |
| Go | `go test -cover` (built into the Go toolchain) | `winget install GoLang.Go` / `brew install go` |
| Rust | `cargo-tarpaulin` or `cargo-llvm-cov` | `cargo install cargo-tarpaulin` / `cargo install cargo-llvm-cov` |

If the project has no detectable tool, the skill returns `[]` (or one `report`-tier note) and exits cleanly.

## Installation

```powershell
# Windows (PowerShell)

# Project-level
Copy-Item -Recurse skills\coverage-check <your-project>\.claude\skills\

# User-level
Copy-Item -Recurse skills\coverage-check ~\.claude\skills\
```

```sh
# Linux / macOS / Git Bash
cp -r skills/coverage-check <your-project>/.claude/skills/   # project-level
cp -r skills/coverage-check ~/.claude/skills/                # user-level
```

If you're using `bin/terrarium-sync-claude`, it lands at the user level along with every other skill.

## Permissions

Git read commands are covered by [`settings\claude\base.json`](../../settings/claude/base.json). The coverage tool itself runs as a Bash command (e.g., `pytest --cov=...`); add the tool to your `permissions.allow` list (or use a per-language preset like [`settings\claude\dotnet.json`](../../settings/claude/dotnet.json)) to avoid prompts.

## Usage

```bash
/coverage-check                              # auto-detect target + tool, no threshold
/coverage-check --target develop             # diff against develop
/coverage-check --coverage-threshold 80      # 80% threshold; below -> soft_block per chunk
/coverage-check --target develop --coverage-threshold 75
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--target` | No | Auto-detected default branch (typically `main`) | Target branch for the diff |
| `--coverage-threshold` | No | Project config, then none | Diff-coverage percent threshold (0–100). Below this → `soft_block` |

## Output

A single JSON object on stdout with a project-level `summary` and a list of per-chunk `findings`:

```json
{
  "summary": {
    "diff_coverage_pct": 67.5,
    "threshold": 80,
    "gap_lines": 14
  },
  "findings": [
    {
      "tier": "soft_block | report",
      "file": "path/to/file",
      "line_start": 42,
      "line_end": 58,
      "chunk_kind": "pure_logic | trivial | untestable | generated",
      "uncovered_lines": [44, 45, 47, 50],
      "message": "short explanation"
    }
  ]
}
```

`summary` is `null` when the run produced no coverage numbers (no tool detected, run failed, or empty diff). `findings` is always an array — empty if there's nothing to flag.

### Chunk kinds (heuristic)

- **`pure_logic`** — branches, conditions, loops, calculations. The "interesting" code. Default for ambiguous chunks. The orchestrator should usually ask for tests.
- **`trivial`** — getters/setters/DTOs/constants/`__repr__`/`ToString`. Auto-generating tests is reasonable, but skipping is also defensible.
- **`untestable`** — defensive panics, unreachable branches, platform-specific shims. The orchestrator should propose an exclusion comment, not write a test.
- **`generated`** — auto-generated code. The orchestrator should add tool-appropriate exclusion markers.

### Tiering

| Threshold present | `diff_coverage_pct` < threshold | Per-chunk tier |
|-------------------|--------------------------------|----------------|
| Yes | Yes | `soft_block` |
| Yes | No | `report` |
| No | n/a | `report` |

## Behavior notes

- **Diff-scoped, not project-scoped.** Coverage is computed on lines added/changed in this branch only. The whole-project number isn't reported.
- **Read-only with respect to source.** The skill never modifies source files. It does run the test suite, which produces coverage artifacts (`coverage.xml`, `coverage.out`, `lcov.info`, etc.) — those are tool side effects, not skill writes.
- **No test writing.** Auto-fixing is the orchestrator's job (e.g., `/implement`'s verify phase writes tests for `pure_logic`/`trivial` chunks and proposes exclusions for `untestable`/`generated`).

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Returns `[]` immediately | The skill could not detect a coverage tool, or the diff is empty. Check `git diff <target>...HEAD --stat`. |
| Coverage run fails | The skill emits a single `report`-tier finding describing the failure. Run the coverage command yourself to debug. |
| Chunks misclassified (e.g., a getter flagged `pure_logic`) | The classifier uses heuristics; ambiguous cases default to `pure_logic`. The orchestrator's user prompt is the right place to override. |
| Threshold doesn't apply | Confirm priority: `--coverage-threshold` > project config > none. With none, all findings are `report`. |
