# Agents

Custom Claude Code subagent definitions.

Agents live at one of:

- `~\.claude\agents\<name>.md` — flat layout (user-level)
- `~\.claude\agents\<name>\<name>.md` — folder layout (user-level), used when the agent ships with co-located resources such as a PreToolUse hook script
- `<project>\.claude\agents\<...>` — same two layouts, project-level

Both layouts are discovered by Claude Code at session start. Use the folder layout when an agent registers hooks in its frontmatter and the hook scripts should ship alongside the agent (so a single sync places everything in one place — see [`verify-runner/`](verify-runner/) for the canonical example).

Agents differ from skills in two important ways:

1. **They run as subagents** — spawned via the `Agent` tool with `subagent_type: "<name>"`. Each invocation gets its own context window separate from the parent's, which is useful when you need to fan out independent work in parallel without polluting the parent's context.
2. **Their tool list is restricted at the harness level** — the `tools:` field in the frontmatter is enforced by Claude Code, so a subagent literally cannot call tools outside that list. This makes agents the right primitive when you need a "this code path can read but not write" guarantee.

## Available agents

| Agent | Purpose | Tools | Layout |
|-------|---------|-------|--------|
| [`verify-runner`](verify-runner/) | Run one verification skill (e.g., `/standards-check`, `/doc-review`, `/coverage-check`, `/review`, `/security-review`, `/simplify`) against the diff and return findings as JSON. Bash restricted to a read-only allowlist by a frontmatter-registered hook. | `Skill, Read, Grep, Glob, Bash` | folder (co-located bash-guard hook) |

## Installation

Agents are synced to user-level via [`bin/seiji-claude-sync-agents`](../bin/README.md), which copies each entry in `agents/` to `~\.claude\agents\`:

- `agents/<name>.md` (flat) → `~\.claude\agents\<name>.md`
- `agents/<name>/` (folder, e.g. `verify-runner/`) → `~\.claude\agents\<name>\` (whole tree)

The wrapper `seiji-claude-sync` calls `seiji-claude-sync-agents` as part of the four-step sync (skills → agents → hooks → settings).

Manual install (if you're not using the sync infrastructure):

```powershell
# Windows (PowerShell) — folder-layout agent
Copy-Item -Recurse agents\verify-runner ~\.claude\agents\
```

```sh
# Linux / macOS / Git Bash — folder-layout agent
cp -r agents/verify-runner ~/.claude/agents/
```

## Agent file format

Each agent is a single markdown file with YAML frontmatter:

```markdown
---
name: agent-name
description: One-line description shown to the parent when picking a subagent
tools: Comma, Separated, List, Of, Tool, Names
model: sonnet | haiku | opus | <other>   # optional
---

The body is the agent's system prompt — what it should do, what its
boundaries are, what its output format is.
```

The parent invokes the agent like this:

```
Agent({
  description: "Run /standards-check on the diff",
  subagent_type: "verify-runner",
  prompt: "<concrete task with all required context>"
})
```

The agent has its own conversation context starting with this prompt. It returns when it's done; its return value flows back to the parent as the `Agent` tool result.

## Why agents and not skills?

Skills are great for "here's a procedure I want a Claude session to follow." Agents are the right primitive when you specifically want:

- **Parallelism**: spawn N independent subagents in one message and they run concurrently.
- **Tool isolation**: the parent stays full-tools while the subagent is restricted (e.g., `verify-runner` can't `Edit`).
- **Context isolation**: the subagent's intermediate work doesn't crowd the parent's context window.

If you don't need any of those, a skill is simpler and more discoverable (no `Agent` tool boilerplate at the call site).

## Defining a new agent

1. Pick a layout:
   - **Flat** (`agents/<name>.md`) for agents that don't need any co-located scripts.
   - **Folder** (`agents/<name>/<name>.md`) when the agent registers a hook in its frontmatter and you want the hook scripts to ship alongside the agent definition.
2. Create the `.md` file at the chosen path with the frontmatter template above.
3. Choose `tools:` carefully — list **only** what the agent legitimately needs. Anything not listed cannot be invoked by the agent.
4. Write the system prompt. State the agent's mission, its boundaries (what it must NOT do), and the expected output format.
5. Test with `Agent(subagent_type: "<name>", prompt: "...")` from a parent session.
6. Sync to user-level via `seiji-claude-sync-agents` (or the wrapper).

For agents that need runtime restrictions beyond the static `tools:` list (e.g., "can run Bash, but only read-only Bash commands"), register a `PreToolUse` hook in the agent's frontmatter `hooks:` block. Per the [Claude Code subagent docs](https://code.claude.com/docs/en/sub-agents#conditional-rules-with-hooks), frontmatter hooks **only run while that specific subagent is active** — the harness scopes them deterministically, no detection logic needed in the script. The [`verify-runner`](verify-runner/) agent uses this pattern with its co-located `verify-runner-bash-guard` script.
