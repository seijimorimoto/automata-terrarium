# verify-runner-bash-guard

A `PreToolUse` hook that restricts Bash commands inside the `verify-runner` subagent (see [`agents/verify-runner.md`](../../agents/verify-runner.md)) to a read-only allowlist. Best-effort — it falls back to a no-op (allow) when verify-runner context cannot be detected from the hook input, so it never accidentally blocks the parent `/implement` or other agents.

## Why this exists

Claude Code's permission system is session-scoped — there's no per-agent allow/deny. The `verify-runner` agent's `tools:` list already excludes `Edit`, `Write`, and `NotebookEdit` (so it physically cannot modify files via the harness), but `Bash` is allowed because verify checks need to run things like `git diff` and `pytest --cov`.

A hook is the only mechanism that can be agent-aware. This hook reads the `PreToolUse` payload, checks whether the call is coming from `verify-runner`, and validates the Bash command against a read-only allowlist if so. Anything else passes through.

## What it allows (when verify-runner is detected)

| Category | Allowed prefixes |
|----------|------------------|
| Read-only git | `git diff`, `git log`, `git show`, `git status`, `git branch` (no `-d`/`-D`/`-m`), `git rev-parse`, `git ls-files`, `git symbolic-ref` |
| Coverage tool reads | `pytest --cov`, `vitest --coverage`, `jest --coverage`, `c8`, `go test -cover`, `dotnet test --collect`, `cargo tarpaulin`, `cargo llvm-cov` |
| JSON tool | `jq` |

Commands containing `rm`, `mv`, `cp`, `curl`, `wget`, write redirection (`>`, `>>`), pipes to `tee`, or `dd` are denied even if the leading command would otherwise be allowlisted.

## How detection works

The hook inspects the PreToolUse stdin payload for any of these fields with the value `verify-runner`:

- `subagent_type` / `subagentType`
- `agent_name` / `agentName`
- `agent` / `agent_type` / `agentType`
- `parent_agent.name`

It also checks the `CLAUDE_SUBAGENT_TYPE` and `CLAUDE_AGENT_NAME` environment variables. If any match, the hook is in **enforcement** mode and validates the command. If none match, the hook is in **fallback** mode and allows everything.

### The probe log

On first run, the hook writes the top-level keys of the input payload to `~/.claude/hooks/verify-runner-bash-guard/probe.log`:

```
first-run keys: tool_name, tool_input, session_id, ...
```

Inspect this file to see which fields the running Claude Code version actually exposes. If you see a field that should identify the subagent (e.g., `subagent_id`), open an issue or extend `Test-VerifyRunner` (PowerShell) / the `is_vr` detection block (bash) in the script.

### The fallback warning

If the hook can't detect verify-runner context, it logs a single warning to `~/.claude/hooks/verify-runner-bash-guard/log` (not per invocation) and leaves a `.fallback-warned` sentinel so subsequent calls don't re-log. In this state, the hook is effectively a no-op — the security model degrades to prompt-level discipline (which the agent definition documents) plus the user's existing global `permissions.allow`/`deny` rules.

That degraded floor is the documented v1 acceptable state. No action is required, but you can:

- Inspect `probe.log` to see whether the harness now exposes a usable field.
- Delete `.fallback-warned` to re-emit the warning on the next call.
- Disable the hook entirely (see below) until the harness offers agent-aware metadata.

## Installation

The hook ships in this repo's `hooks/verify-runner-bash-guard/` folder. Two ways to install:

**Recommended — via `seiji-claude-sync`:**

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-install.ps1     # one-time, if you haven't yet
seiji-claude-sync                  # syncs scripts AND merges settings
```

```sh
# Linux / macOS / Git Bash
./bin/seiji-claude-install
seiji-claude-sync
```

The sync wrapper runs `seiji-claude-sync-hooks` (which copies the hook scripts to `~/.claude/hooks/verify-runner-bash-guard/`) and then `seiji-claude-sync-settings` (which merges `settings/verify-runner-bash-guard.json` into `~/.claude/settings.json`). After that, the hook is registered.

**Manual:**

```powershell
# Copy the hook
Copy-Item -Recurse hooks\verify-runner-bash-guard ~\.claude\hooks\

# Add this to ~/.claude/settings.json under "hooks":
# (or merge by hand — see settings/verify-runner-bash-guard.json for the snippet)
```

## How to disable

Remove the registration from `~/.claude/settings.json`:

```jsonc
{
  "hooks": {
    "PreToolUse": [
      // delete the entry whose command points at verify-runner-bash-guard
    ]
  }
}
```

You can leave the script file in place — the harness only runs hooks that are registered.

## Logs

| File | Purpose |
|------|---------|
| `~/.claude/hooks/verify-runner-bash-guard/probe.log` | Top-level keys of the first PreToolUse payload (one-time) |
| `~/.claude/hooks/verify-runner-bash-guard/log` | Operational log — fallback warnings, missing-jq notices |
| `~/.claude/hooks/verify-runner-bash-guard/.fallback-warned` | Sentinel preventing repeated fallback warnings |

## Limitations

- **Best-effort.** If the harness doesn't expose agent-type metadata to PreToolUse hooks in your Claude Code version, the hook is a no-op. The verify-runner agent's prompt is the floor of the security model — the agent is told to self-restrict Bash commands.
- **Process boundaries.** This hook only sees what the harness passes via stdin. It can't introspect the running Claude session in any other way.
- **POSIX requires `jq`.** The bash variant uses jq for safe JSON parsing. If jq isn't on PATH, the hook logs a notice and allows. The PowerShell variant has no extra dependencies.
