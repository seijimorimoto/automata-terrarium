# verify-runner

A read-only verification subagent. `/implement`'s verify phase fans out one `verify-runner` per check (`/standards-check`, `/review`, `/security-review`, `/doc-review`, `/simplify`, `/coverage-check`) so each runs in its own context window in parallel and returns findings as JSON.

This folder contains the agent definition plus the co-located PreToolUse hook (`verify-runner-bash-guard`) that enforces a read-only Bash allowlist.

## Files

| File | Purpose |
|------|---------|
| [`verify-runner.md`](verify-runner.md) | The agent definition (frontmatter + system prompt). Registers the bash-guard hook in its `hooks:` block. |
| [`verify-runner-bash-guard.ps1`](verify-runner-bash-guard.ps1) | PreToolUse hook (Windows). Validates Bash commands against a read-only allowlist. |
| [`verify-runner-bash-guard.sh`](verify-runner-bash-guard.sh) | PreToolUse hook (POSIX, requires `jq`). Same validator, bash variant. |

## Why the hook exists

The agent's `tools:` list already excludes `Edit`, `Write`, and `NotebookEdit` — the harness ensures the agent physically cannot modify files via those tools. `Bash` is allowed because verify checks need to run things like `git diff` and `pytest --cov`, and the hook prevents that Bash channel from being a back door for mutation.

## Hook scope and registration

The hook is registered via the `hooks:` block in [`verify-runner.md`](verify-runner.md)'s frontmatter, not via `~/.claude/settings.json`. Per the [Claude Code subagent docs](https://code.claude.com/docs/en/sub-agents#conditional-rules-with-hooks), frontmatter hooks **only run while that specific subagent is active** and are cleaned up when it finishes. That means:

- The hook only runs inside `verify-runner` — never in the parent `/implement` session, never in other agents.
- No payload-field probing, no detection heuristics, no fallback. The harness does the scoping.
- No entry in `~/.claude/settings.json`.

The frontmatter `command:` value is:

```text
pwsh -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/agents/verify-runner/verify-runner-bash-guard.ps1"
```

PowerShell expands `$HOME` to the user's home regardless of OS, and the `~/.claude/agents/verify-runner/` path is where `seiji-claude-sync-agents` installs this folder. POSIX users who prefer the bash variant: edit the `command:` line in `verify-runner.md` to:

```text
bash "$HOME/.claude/agents/verify-runner/verify-runner-bash-guard.sh"
```

## What the hook allows

| Category | Allowed prefixes |
|----------|------------------|
| Read-only git | `git diff`, `git log`, `git show`, `git status`, `git branch` (no `-d`/`-D`/`-m`), `git rev-parse`, `git ls-files`, `git symbolic-ref` |
| Coverage tool reads | `pytest --cov`, `vitest --coverage`, `jest --coverage`, `c8`, `go test -cover`, `dotnet test --collect`, `cargo tarpaulin`, `cargo llvm-cov` |
| JSON tool | `jq` |

Commands containing `rm`, `mv`, `cp`, `curl`, `wget`, write redirection (`>`, `>>`), pipes to `tee`, or `dd` are denied even if the leading command would otherwise be allowlisted (e.g., `git diff && rm -rf .`).

## Hook output convention

Per the [Claude Code hooks docs](https://code.claude.com/docs/en/hooks#exit-code-output):

- **Exit 0** — allow the Bash call.
- **Exit 2** — block the Bash call. The script's stderr message is fed back to Claude as the deny reason.
- Any other exit code is treated by the harness as a non-blocking error.

The script writes nothing to stdout in either case.

## Installation

Run `seiji-claude-sync` from the repo root (or `seiji-claude-sync-agents` alone if you only want agents). That copies this whole folder to `~/.claude/agents/verify-runner/`. Once the agent file is in place, the harness picks up the frontmatter hook automatically — no settings merge needed.

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-install.ps1   # one-time PATH setup
seiji-claude-sync                # syncs skills, agents, hooks, settings
```

```sh
# Linux / macOS / Git Bash
./bin/seiji-claude-install
seiji-claude-sync
```

## How to disable

Remove or rename the `hooks:` block in `~/.claude/agents/verify-runner/verify-runner.md`. The agent will still work — it just won't enforce the read-only Bash allowlist anymore. The verify-runner system prompt's defense-in-depth language tells the agent to self-restrict, so removing the hook isn't catastrophic for already-trusted models, but you lose the harness-enforced backstop.

## Limitations

- **POSIX requires `jq`.** The bash variant uses jq for safe JSON parsing. If jq isn't on PATH, the hook logs a notice on stderr and allows.
- **PowerShell-default `command:`.** The frontmatter ships with the `.ps1` invocation. POSIX users who don't have PowerShell installed should swap to the `.sh` variant per the snippet above.
- **Path is hardcoded to `$HOME/.claude/agents/verify-runner/`.** The hook script is found via that path, so the agent must be installed at user level. Project-level installation (`<project>/.claude/agents/verify-runner/`) would require editing the `command:` to use `"$CLAUDE_PROJECT_DIR/.claude/agents/verify-runner/..."`.
