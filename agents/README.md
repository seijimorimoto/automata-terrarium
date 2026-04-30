# Agents

Custom Claude Code subagent definitions.

Agents live at `~\.claude\agents\<name>.md` (user-level) or `<project>\.claude\agents\<name>.md` (project-level). They differ from skills in two important ways:

1. **They run as subagents** — spawned via the `Agent` tool with `subagent_type: "<name>"`. Each invocation gets its own context window separate from the parent's, which is useful when you need to fan out independent work in parallel without polluting the parent's context.
2. **Their tool list is restricted at the harness level** — the `tools:` field in the frontmatter is enforced by Claude Code, so a subagent literally cannot call tools outside that list. This makes agents the right primitive when you need a "this code path can read but not write" guarantee.

## Available agents

| Agent | Purpose | Tools |
|-------|---------|-------|
| [`verify-runner`](verify-runner.md) | Run one verification skill (e.g., `/standards-check`, `/doc-review`, `/coverage-check`, `/review`, `/security-review`, `/simplify`) against the diff and return findings as JSON | `Skill, Read, Grep, Glob, Bash` |

## Installation

Agents are synced to user-level via [`bin/seiji-claude-sync-agents`](../bin/README.md), which copies every file in `agents/` to `~\.claude\agents\<name>.md`. The wrapper `seiji-claude-sync` calls it as part of the four-step sync (skills → agents → hooks → settings).

Manual install (if you're not using the sync infrastructure):

```powershell
# Windows (PowerShell)
Copy-Item agents\verify-runner.md ~\.claude\agents\
```

```sh
# Linux / macOS / Git Bash
cp agents/verify-runner.md ~/.claude/agents/
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

1. Create `agents/<name>.md` with the frontmatter template above.
2. Choose `tools:` carefully — list **only** what the agent legitimately needs. Anything not listed cannot be invoked by the agent.
3. Write the system prompt. State the agent's mission, its boundaries (what it must NOT do), and the expected output format.
4. Test with `Agent(subagent_type: "<name>", prompt: "...")` from a parent session.
5. Sync to user-level via `seiji-claude-sync-agents` (or the wrapper).

For agents that need **best-effort** runtime restrictions beyond the static `tools:` list (e.g., "can run Bash, but only read-only Bash commands"), pair the agent definition with a `PreToolUse` hook that inspects each Bash call and denies anything outside an allowlist. The `verify-runner` agent uses this pattern with the [`verify-runner-bash-guard`](../hooks/verify-runner-bash-guard/) hook.
