# Agents

Custom Claude Code subagent definitions and GitHub Copilot CLI custom agent profiles.

Support markers: `✅` supported, `❌` not supported, `⚠️` partial/manual/planned.

**Convention in this repo: every agent lives in its own folder.** The agent's markdown file, its README, and any co-located resources (hook scripts, helpers, fixtures) sit alongside each other. This mirrors the `skills/<name>/SKILL.md` shape and keeps agents that are flat today ready to gain a hook tomorrow without any migration.

```
agents/<name>/
├── <name>.md        ← Claude Code agent definition (YAML frontmatter + system prompt)
├── <name>.agent.md  ← Copilot custom agent profile when supported
├── README.md        ← what the agent does, how it's installed, any caveats
└── scripts/         ← optional: hook scripts, helpers, fixtures
    └── ...
```

Implementation files (hook scripts, helpers, anything the agent's frontmatter references) go under `scripts/` — same convention as skills (`skills/<name>/scripts/`). Anything that is not the agent's "API surface" (the `.md` and the `README.md`) belongs there. Other implementation-detail subdirectories (e.g., `fixtures/`, `assets/`) follow the same pattern.

Synced to Claude user-level, that becomes `~\.claude\agents\<name>\<name>.md` (or `<project>\.claude\agents\<name>\...` at project level). Copilot variants sync to `~\.copilot\agents\` or can be copied to `<project>\.github\agents\`.

Flat-layout agents (`agents/<name>.md`) are still supported by the sync script for compatibility with hand-authored or third-party agents that ship that way, but new agents in this repo should follow the folder convention.

Agents differ from skills in two important ways:

1. **They run as subagents** — spawned via the `Agent` tool with `subagent_type: "<name>"`. Each invocation gets its own context window separate from the parent's, which is useful when you need to fan out independent work in parallel without polluting the parent's context.
2. **Their tool list is restricted at the harness level** — the `tools:` field in the frontmatter is enforced by Claude Code, so a subagent literally cannot call tools outside that list. This makes agents the right primitive when you need a "this code path can read but not write" guarantee.

## Available agents

| Agent | Claude Code | Copilot CLI | Purpose | Tools |
|-------|-------------|-------------|---------|-------|
| [`verify-runner`](verify-runner/) | ✅ | ⚠️ | Run one verification check against the diff and return findings as JSON. | Claude: `Skill, Read, Grep, Glob, Bash`; Copilot: planned custom agent tools |

## Installation

Claude agents are synced to user-level via [`bin\seiji-claude-sync-agents`](..\bin\README.md), which copies each `agents\<name>\` folder to `~\.claude\agents\<name>\` (whole tree). Copilot agent sync is planned and will copy `.agent.md` profiles to `~\.copilot\agents\`.

The script also accepts flat `agents/<name>.md` entries for compatibility with externally-authored agents, but everything in this repo follows the folder convention.

Manual install (if you're not using the sync infrastructure):

```powershell
# Windows (PowerShell)
Copy-Item -Recurse agents\verify-runner ~\.claude\agents\

# Copilot user-level (once Copilot variants exist)
Copy-Item agents\verify-runner\verify-runner.agent.md ~\.copilot\agents\
```

```sh
# Linux / macOS / Git Bash
cp -r agents/verify-runner ~/.claude/agents/

# Copilot user-level (once Copilot variants exist)
cp agents/verify-runner/verify-runner.agent.md ~/.copilot/agents/
```

## Agent file format

Each Claude agent is a single markdown file with YAML frontmatter:

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

1. Create the agent folder: `agents/<name>/`.
2. Inside, create `agents/<name>/<name>.md` for Claude Code and `agents/<name>/<name>.agent.md` for Copilot CLI when supported.
3. Add `agents/<name>/README.md` describing what the agent does, install steps, and any caveats.
4. Choose `tools:` carefully — list **only** what the agent legitimately needs. Anything not listed cannot be invoked by the agent.
5. Write the system prompt. State the agent's mission, its boundaries (what it must NOT do), and the expected output format.
6. Test with `Agent(subagent_type: "<name>", prompt: "...")` from a parent session.
7. Sync to user-level via `seiji-claude-sync-agents` (or the wrapper).

For agents that need runtime restrictions beyond the static `tools:` list (e.g., "can run Bash, but only read-only Bash commands"), register a `PreToolUse` hook in the agent's frontmatter `hooks:` block and ship the script under `agents/<name>/scripts/` (e.g., `agents/<name>/scripts/<name>-bash-guard.ps1`). Per the [Claude Code subagent docs](https://code.claude.com/docs/en/sub-agents#conditional-rules-with-hooks), frontmatter hooks **only run while that specific subagent is active** — the harness scopes them deterministically, no detection logic needed in the script. The [`verify-runner`](verify-runner/) agent uses this pattern with its co-located [`scripts/verify-runner-bash-guard`](verify-runner/scripts/) script.
