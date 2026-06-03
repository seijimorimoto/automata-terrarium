# Azure DevOps PR Integration Skills

These skills bring GitHub-like PR session linking to Azure DevOps for Claude Code. When you create a PR using `/ado-pr`, Claude Code automatically links it to your current session, allowing you to resume work on that PR later.

Copilot CLI can create PRs with the `/ado-pr` Copilot skill variant, but the session-linking workflow depends on Claude skill-scoped hooks. Copilot CLI does not support skill-frontmatter-scoped hooks, so `/ado-resume-pr` and `/ado-pr-status` are not planned for Copilot CLI.

## Prerequisites

- **Azure CLI** — [Install guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Azure DevOps extension** — Install with: `az extension add --name azure-devops`
- **Authenticated with Azure DevOps** — Sign in with: `az login`
- **Windows PowerShell 5.1+** — Included with Windows

## Available Skills

| Skill | Claude Code | Copilot CLI | Description | Notes |
|-------|-------------|-------------|-------------|-------|
| `/ado-pr` | ✅ | ⚠️ | Create a pull request in Azure DevOps with standardized formatting | Copilot supports PR creation only; automatic session capture is Claude-only because it uses a skill-scoped hook. |
| `/ado-resume-pr [NUMBER]` | ✅ | ❌ | Resume the Claude session that created a specific PR | Not planned for Copilot CLI because it depends on the Claude session database populated by `/ado-pr`'s skill-scoped hook. |
| `/ado-pr-status [--all]` | ✅ | ❌ | List all tracked PRs (current repo or all repos) | Not planned for Copilot CLI because it reads the Claude session database populated by `/ado-pr`'s skill-scoped hook. |

## Installation

Copy the supported skill folders to a runtime location:

- **Claude project-level** (one project): `<project-root>\.claude\skills\`
- **Claude user-level** (all projects): `~\.claude\skills\`
- **Copilot project-level** (one project): `<project-root>\.github\skills\`
- **Copilot user-level** (all projects): `~\.copilot\skills\`

```powershell
# Windows (PowerShell)

# All ADO skills (project-level)
Copy-Item -Recurse skills\ado-pr, skills\ado-resume-pr, skills\ado-pr-status <your-project>\.claude\skills\

# All ADO skills (user-level)
Copy-Item -Recurse skills\ado-pr, skills\ado-resume-pr, skills\ado-pr-status ~\.claude\skills\

# Copilot user-level for ado-pr only
Copy-Item -Recurse skills\ado-pr ~\.copilot\skills\

# Or symlink them (project-level)
New-Item -ItemType SymbolicLink -Path <your-project>\.claude\skills\ado-pr -Target (Resolve-Path skills\ado-pr)
New-Item -ItemType SymbolicLink -Path <your-project>\.claude\skills\ado-resume-pr -Target (Resolve-Path skills\ado-resume-pr)
New-Item -ItemType SymbolicLink -Path <your-project>\.claude\skills\ado-pr-status -Target (Resolve-Path skills\ado-pr-status)
```

```sh
# Linux / macOS

# All ADO skills (project-level)
cp -r skills/ado-pr skills/ado-resume-pr skills/ado-pr-status <your-project>/.claude/skills/

# All ADO skills (user-level)
cp -r skills/ado-pr skills/ado-resume-pr skills/ado-pr-status ~/.claude/skills/

# Copilot user-level for ado-pr only
cp -r skills/ado-pr ~/.copilot/skills/

# Or symlink them (project-level)
ln -s "$(pwd)/skills/ado-pr" <your-project>/.claude/skills/ado-pr
ln -s "$(pwd)/skills/ado-resume-pr" <your-project>/.claude/skills/ado-resume-pr
ln -s "$(pwd)/skills/ado-pr-status" <your-project>/.claude/skills/ado-pr-status
```

For project-level installs, the skills are available to anyone who clones the target project — no extra setup beyond the prerequisites.

---

## Skill Details

### `/ado-pr` - Create Pull Request

Creates a PR with standardized formatting (title format: `[ProjectName] Description`, sections: Summary, Key Changes, Impact, Risk & Mitigation, Validation).

```bash
/ado-pr                                    # Create PR to the default branch
/ado-pr --target develop                   # Target different branch
/ado-pr --title "[ServiceName] Custom"     # Custom title
```

[Full documentation](SKILL.claude.md) and [Copilot variant](SKILL.copilot.md)

### `/ado-resume-pr` - Resume Session by PR Number

Look up and resume the Claude session that created a specific PR. This is Claude-only because it depends on the Claude session database populated by a skill-scoped hook.

```bash
/ado-resume-pr 12345
```

[Full documentation](../ado-resume-pr/SKILL.claude.md)

### `/ado-pr-status` - List Tracked PRs

View all PRs linked to Claude sessions. This is Claude-only because it depends on the Claude session database populated by a skill-scoped hook.

```bash
/ado-pr-status          # Current repo
/ado-pr-status --all    # All repos
```

[Full documentation](../ado-pr-status/SKILL.claude.md)

---

## Claude Code PR Session Linking

### Automatic Capture (Skill-Scoped Hook)

When you create a PR using `/ado-pr`, a skill-scoped hook automatically runs:
1. Extracts the PR number and URL from Azure CLI output
2. Records your current session ID
3. Stores the mapping in `~\.claude\ado-pr-sessions.json`

The hook is scoped to the `/ado-pr` skill, so it only executes during PR creation -- not on every Bash command.

Copilot CLI does not support skill-frontmatter-scoped hooks. Although Copilot supports lifecycle/tool hooks through JSON/settings configuration, those hooks are not scoped by declaring them in a skill's frontmatter. This is why the Copilot `/ado-pr` variant is PR-creation-only and why `/ado-resume-pr` and `/ado-pr-status` are not planned for Copilot CLI.

### Session Database

The session database is stored locally at `~\.claude\ado-pr-sessions.json`:

```json
{
  "MyProject": {
    "12345": {
      "session_id": "abc123def456",
      "pr_url": "https://dev.azure.com/.../pullrequest/12345",
      "branch": "u/user/feature-branch",
      "repository_url": "https://dev.azure.com/.../MyProject",
      "created_at": "2026-02-05T18:17:24Z"
    }
  },
  "AnotherProject": {
    "67890": { "..." : "..." }
  }
}
```

This file is:
- Stored in your home directory (`~\.claude\`), not in any repo
- Unique to each team member
- Never committed to git
- Shared across all your Azure DevOps projects

### Repository-Aware Lookup

The system automatically detects your current repository and looks up PRs accordingly. PR numbers are scoped per repository, so PR #123 in one project won't conflict with PR #123 in another.

---

## Troubleshooting

### Hook not capturing PR information
1. **Verify Azure CLI is installed:**
   ```bash
   az --version
   ```

2. **Ensure PR was created via `/ado-pr`** -- The hook only runs for the skill, not manual commands

3. **Check the hook log file** for errors:
   ```powershell
   Get-Content "$env:USERPROFILE\.claude\logs\ado-pr\capture-pr-hook.log" -Tail 20
   ```

### Can't find PR when resuming
1. **Check you're in the correct repository** -- The system looks up PRs by repo name
2. **Verify PR was created using `/ado-pr`** -- Manual PRs aren't tracked
3. **Run `/ado-pr-status`** to see all tracked PRs in the current repository

### Session database not created
- The database is created automatically on first PR creation
- Location: `~\.claude\ado-pr-sessions.json`
- Must be writable by your user account

### PR creation fails
1. **Check Azure DevOps extension is installed:**
   ```bash
   az extension list
   ```

2. **Ensure you're authenticated:**
   ```bash
   az login
   az account show
   ```

3. **Verify you have permissions** to create PRs in the repository

---

## Comparison: Azure DevOps vs GitHub

| Feature | GitHub (native) | Azure DevOps (custom) |
|---------|-----------------|----------------------|
| Create PR | `/commit-push-pr` | `/ado-pr` |
| Auto-link session | Automatic | Automatic (via hook) |
| Resume by PR | `claude --from-pr 123` | `/ado-resume-pr 123` |
| List tracked PRs | -- | `/ado-pr-status` |
| Cross-repo tracking | Yes | Yes |
| Standardized format | -- | Yes |

---

## Resources

- [Claude Code Documentation](https://docs.claude.ai/claude-code)
- [Azure DevOps CLI Reference](https://learn.microsoft.com/en-us/cli/azure/service-page/azure%20devops)

---

**Last updated:** 2026-02-22
