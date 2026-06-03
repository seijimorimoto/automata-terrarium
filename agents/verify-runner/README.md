# verify-runner

A read-only verification agent. `/implement`'s verify phase fans out one `verify-runner` per check (`/standards-check`, `/review`, `/security-review`, `/doc-review`, `/simplify`, `/coverage-check`) so each runs in its own context window in parallel and returns findings as JSON.

This folder contains Claude Code and Copilot CLI source variants. The Claude Code variant also ships a co-located PreToolUse hook (`verify-runner-bash-guard`) that enforces a read-only Bash allowlist.

## Support

| Runtime | Support | Notes |
|---------|---------|-------|
| Claude Code | ✅ | Uses `verify-runner.claude.md` and the frontmatter-scoped Bash guard. |
| Copilot CLI | ⚠️ | Uses `verify-runner.copilot.md` with restricted tools and self-restriction instructions, but does not yet have an equivalent per-agent Bash guard. |

## Files

| File | Purpose |
|------|---------|
| [`verify-runner.claude.md`](verify-runner.claude.md) | Claude Code source definition. Registers the bash-guard hook in its `hooks:` block and installs as `verify-runner.md`. |
| [`verify-runner.copilot.md`](verify-runner.copilot.md) | Copilot CLI source profile. Installs as `verify-runner.agent.md`. |
| [`scripts/verify-runner-bash-guard.ps1`](scripts/verify-runner-bash-guard.ps1) | PreToolUse hook (Windows). Validates Bash commands against a read-only allowlist. |
| [`scripts/verify-runner-bash-guard.sh`](scripts/verify-runner-bash-guard.sh) | PreToolUse hook (POSIX, requires `jq`). Same validator, bash variant. |

Implementation scripts live under `scripts/` per the repo's convention (mirrors `skills/<name>/scripts/`).

## Installation

Install the agent with the runtime-specific sync script. The sync scripts rename source variants to the filename expected by each tool.

### Claude Code

`seiji-claude-sync-agents` installs `verify-runner.claude.md` as `~\.claude\agents\verify-runner\verify-runner.md` and copies the `scripts\` folder needed by the Claude-specific hook.

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-install.ps1   # one-time PATH setup
seiji-claude-sync-agents
```

```sh
# Linux / macOS / Git Bash
./bin/seiji-claude-install
seiji-claude-sync-agents
```

### Copilot CLI

`seiji-copilot-sync-agents.ps1` installs `verify-runner.copilot.md` as `~\.copilot\agents\verify-runner.agent.md`.

```powershell
# Windows (PowerShell)
.\bin\seiji-copilot-sync-agents.ps1
```

```sh
# Linux / macOS / Git Bash
# POSIX Copilot sync is planned. Manual install:
mkdir -p ~/.copilot/agents
cp agents/verify-runner/verify-runner.copilot.md ~/.copilot/agents/verify-runner.agent.md
```

## Claude Code hook guard

The sections below are specific to Claude Code. Copilot CLI supports hooks, but not this repo's current agent-frontmatter-scoped Bash guard pattern for `verify-runner`.

### Why the hook exists

The agent's `tools:` list already excludes `Edit`, `Write`, and `NotebookEdit` — the harness ensures the agent physically cannot modify files via those tools. `Bash` is allowed because verify checks need to run things like `git diff` and `pytest --cov`, and the hook prevents that Bash channel from being a back door for mutation.

### Hook scope and registration

The hook is registered via the `hooks:` block in [`verify-runner.claude.md`](verify-runner.claude.md)'s frontmatter, not via `~\.claude\settings.json`. Per the Claude Code subagent docs, frontmatter hooks **only run while that specific subagent is active** and are cleaned up when it finishes. That means:

- The hook only runs inside `verify-runner` — never in the parent `/implement` session, never in other agents.
- No payload-field probing, no detection heuristics, no fallback. The harness does the scoping.
- No entry in `~\.claude\settings.json`.

The frontmatter `command:` value is:

```text
pwsh -NoProfile -ExecutionPolicy Bypass -File "$HOME/.claude/agents/verify-runner/scripts/verify-runner-bash-guard.ps1"
```

PowerShell expands `$HOME` to the user's home regardless of OS, and the `~\.claude\agents\verify-runner\` path is where `seiji-claude-sync-agents` installs this folder. POSIX users who prefer the bash variant: edit the `command:` line in the installed `verify-runner.md` to:

```text
bash "$HOME/.claude/agents/verify-runner/scripts/verify-runner-bash-guard.sh"
```

### What the hook allows

| Category | Allowed prefixes |
|----------|------------------|
| Read-only git | `git diff`, `git log`, `git show`, `git status`, `git branch` (no `-d`/`-D`/`-m`), `git rev-parse`, `git ls-files`, `git symbolic-ref` |
| Coverage tool reads | `pytest --cov`, `vitest --coverage`, `jest --coverage`, `c8`, `go test -cover`, `dotnet test --collect`, `cargo tarpaulin`, `cargo llvm-cov` |
| JSON tool | `jq` |

Commands containing `rm`, `mv`, `cp`, `curl`, `wget`, write redirection (`>`, `>>`), pipes to `tee`, or `dd` are denied even if the leading command would otherwise be allowlisted (e.g., `git diff && rm -rf .`).

### Hook output convention

Per the [Claude Code hooks docs](https://code.claude.com/docs/en/hooks#exit-code-output):

- **Exit 0** — allow the Bash call.
- **Exit 2** — block the Bash call. The script's stderr message is fed back to Claude as the deny reason.
- Any other exit code is treated by the harness as a non-blocking error.

The script writes nothing to stdout in either case.

### How to disable

Remove or rename the `hooks:` block in `~\.claude\agents\verify-runner\verify-runner.md`. The agent will still work — it just won't enforce the read-only Bash allowlist anymore. The verify-runner system prompt's defense-in-depth language tells the agent to self-restrict, so removing the hook isn't catastrophic for already-trusted models, but you lose the harness-enforced backstop.

## Limitations

- **POSIX requires `jq`.** The bash variant uses jq for safe JSON parsing. If jq isn't on PATH, the hook logs a notice on stderr and allows.
- **PowerShell-default `command:`.** The frontmatter ships with the `.ps1` invocation. POSIX users who don't have PowerShell installed should swap to the `.sh` variant per the snippet above.
- **Path is hardcoded to `~\.claude\agents\verify-runner\scripts\`** (rendered by PowerShell from `$HOME` in the frontmatter command). The hook script is found via that path, so the agent must be installed at user level. Project-level installation (`<project>\.claude\agents\verify-runner\`) would require editing the `command:` to use the literal shell expression `"$CLAUDE_PROJECT_DIR/.claude/agents/verify-runner/scripts/..."` (forward slashes are kept inside the YAML string, matching the rest of the frontmatter command).
- **Copilot guard parity is not complete.** Copilot CLI supports hooks, but this repo has not yet implemented a Copilot hook that is scoped equivalently to this agent and enforces the same Bash allowlist. The Copilot profile relies on tool restriction plus prompt-level self-restriction.
