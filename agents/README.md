# Agents

Custom subagent and custom-agent profiles for Claude Code and GitHub Copilot CLI.

Support markers: `✅` supported, `❌` not supported, `⚠️` partial/manual/planned.

**Convention in this repo: every agent lives in its own folder.** Agent source files, the agent README, and any co-located resources (hook scripts, helpers, fixtures) sit alongside each other. This mirrors the skill variant shape and keeps each runtime's source explicit.

```
agents/<name>/
├── <name>.claude.md   ← Claude Code source definition when runtime-specific
├── <name>.copilot.md  ← Copilot CLI source profile when runtime-specific
├── <name>.md          ← shared source only when valid for both runtimes
├── README.md        ← what the agent does, how it's installed, any caveats
└── scripts/         ← optional: hook scripts, helpers, fixtures
    └── ...
```

Implementation files (hook scripts, helpers, anything the agent frontmatter references) go under `scripts\` — same convention as skills (`skills\<name>\scripts\`). Anything that is not the agent's API surface belongs there. Other implementation-detail subdirectories (e.g., `fixtures\`, `assets\`) follow the same pattern.

Sync scripts install source variants using each runtime's expected filename:

- Claude Code: `agents\<name>\<name>.claude.md` installs as `~\.claude\agents\<name>\<name>.md`.
- Copilot CLI: `agents\<name>\<name>.copilot.md` installs as `~\.copilot\agents\<name>.agent.md`.
- Shared source: `agents\<name>\<name>.md` may be used only when the same file is valid for both runtimes.

Flat-layout agents at `agents\<name>.md` are still supported by the Claude sync script for compatibility with externally-authored agents, but new agents in this repo should follow the folder convention.

Agents differ from skills in three important ways:

1. **They run in a separate agent context** — useful when you need to fan out independent work in parallel without polluting the parent context.
2. **Their tool list is restricted by the runtime** — both Claude Code and Copilot custom agents support tool lists, but tool names and enforcement details differ.
3. **Runtime-specific hooks differ** — Claude Code supports frontmatter-scoped hooks for an agent. Copilot CLI supports hooks too, but its documented hooks are configured as JSON/settings lifecycle hooks and are not skill- or agent-frontmatter-scoped.

## Available agents

| Agent | Claude Code | Copilot CLI | Purpose | Tools | Notes / limitations |
|-------|-------------|-------------|---------|-------|---------------------|
| [`verify-runner`](verify-runner/) | ✅ | ⚠️ | Run one verification check against the diff and return findings as JSON. | Claude: `Skill, Read, Grep, Glob, Bash`; Copilot: `read, search, execute` | Copilot profile self-restricts shell usage; Copilot does not support the Claude-style agent-frontmatter-scoped Bash guard used by this repo. |

## Installation

Agent sources are synced to user-level via the runtime-specific sync scripts:

- Claude Code: [`bin\seiji-claude-sync-agents`](..\bin\README.md) copies each `agents\<name>\` folder to `~\.claude\agents\<name>\` and installs `<name>.claude.md` as `<name>.md`.
- Copilot CLI: `bin\seiji-copilot-sync-agents.ps1` installs `<name>.copilot.md` as `~\.copilot\agents\<name>.agent.md`.

The Claude script also accepts flat `agents\<name>.md` entries for compatibility with externally-authored agents, but new agents in this repo should follow the folder convention.

Manual install (if you're not using the sync infrastructure) must rename source variants to the runtime filenames:

```powershell
# Windows (PowerShell)

# Claude Code user-level path
New-Item -ItemType Directory -Path ~\.claude\agents\verify-runner -Force
Copy-Item -Recurse agents\verify-runner\scripts ~\.claude\agents\verify-runner\
Copy-Item agents\verify-runner\verify-runner.claude.md ~\.claude\agents\verify-runner\verify-runner.md

# Copilot CLI user-level path
New-Item -ItemType Directory -Path ~\.copilot\agents -Force
Copy-Item agents\verify-runner\verify-runner.copilot.md ~\.copilot\agents\verify-runner.agent.md
```

```sh
# Linux / macOS / Git Bash

# Claude Code user-level path
mkdir -p ~/.claude/agents/verify-runner
cp -r agents/verify-runner/scripts ~/.claude/agents/verify-runner/
cp agents/verify-runner/verify-runner.claude.md ~/.claude/agents/verify-runner/verify-runner.md

# Copilot CLI user-level path
mkdir -p ~/.copilot/agents
cp agents/verify-runner/verify-runner.copilot.md ~/.copilot/agents/verify-runner.agent.md
```

## Agent file format

Each source file is Markdown with YAML frontmatter plus the agent prompt body. Use target-specific files when runtime frontmatter differs.

Claude Code source example (`<name>.claude.md`):

```markdown
---
name: agent-name
description: One-line description shown to the parent when picking a subagent
tools: Comma, Separated, List, Of, Tool, Names
model: sonnet | haiku | opus | <other>   # optional
hooks: ...                               # optional, Claude-specific
---
```

Copilot CLI source example (`<name>.copilot.md`):

```markdown
---
name: agent-name
description: One-line description shown when selecting or invoking the custom agent
tools: ["read", "search", "execute"]
---

The body is the agent's system prompt — what it should do, what its
boundaries are, what its output format is.
```

Runtime invocation differs:

- Claude Code can spawn an installed subagent by `subagent_type`.
- Copilot CLI can select a custom agent with `/agent`, infer it from a prompt, or launch with `copilot --agent=<name>`.

Claude Code parent invocation example:

```
Agent({
  description: "Run /standards-check on the diff",
  subagent_type: "verify-runner",
  prompt: "<concrete task with all required context>"
})
```

The agent has its own conversation context starting with this prompt. Its return value flows back to the parent runtime when it finishes.

## Why agents and not skills?

Skills are great for "here's a procedure I want the current agent session to follow." Agents are the right primitive when you specifically want:

- **Parallelism**: spawn N independent subagents in one message and they run concurrently.
- **Tool isolation**: the parent stays full-tools while the subagent/custom agent is restricted (e.g., `verify-runner` should not edit files).
- **Context isolation**: the subagent's intermediate work doesn't crowd the parent's context window.

If you don't need any of those, a skill is simpler and more discoverable (no `Agent` tool boilerplate at the call site).

## Defining a new agent

1. Create the agent folder: `agents\<name>\`.
2. Inside, create `agents\<name>\<name>.claude.md` and/or `agents\<name>\<name>.copilot.md`. Use `agents\<name>\<name>.md` only when the source is truly shared.
3. Add `agents\<name>\README.md` describing what the agent does, install steps, support status, and any caveats.
4. Choose `tools:` carefully — list **only** what the agent legitimately needs. Anything not listed cannot be invoked by the agent.
5. Write the system prompt. State the agent's mission, its boundaries (what it must NOT do), and the expected output format.
6. Test with the target runtime (`Agent(subagent_type: "<name>", prompt: "...")` for Claude Code, `/agent` or `copilot --agent=<name>` for Copilot CLI).
7. Sync to user-level via the matching sync script.

For agents that need runtime restrictions beyond the static `tools:` list (e.g., "can run shell commands, but only read-only commands"), use the strongest runtime-supported guard:

- Claude Code: register a `PreToolUse` hook in the agent frontmatter `hooks:` block and ship the script under `agents\<name>\scripts\`. Frontmatter hooks are scoped to that specific agent.
- Copilot CLI: use the custom agent `tools` list and, when needed, separate Copilot hook JSON/settings. Copilot hooks are supported, but they are not skill- or agent-frontmatter-scoped, so they are not a direct replacement for the Claude `verify-runner` Bash guard.

The [`verify-runner`](verify-runner/) agent uses the Claude frontmatter hook pattern with its co-located [`scripts\verify-runner-bash-guard`](verify-runner/scripts/) script. The Copilot variant is therefore marked `⚠️` because Copilot cannot use that per-agent frontmatter hook pattern.
