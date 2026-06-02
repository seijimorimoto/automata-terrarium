---
name: ado-pr
description: Create a pull request in Azure DevOps with standardized formatting
---

# Azure DevOps Pull Request Creator

Creates a pull request in Azure DevOps with a standardized title and description.

## Usage

```copilot
Use the /ado-pr skill
Use the /ado-pr skill with --target develop
Use the /ado-pr skill with --title "[ReadServices] Add authentication middleware"
```

## Instructions

When this skill is invoked:

1. Inspect the branch and changes:
   - `git status`
   - `git diff --staged`
   - `git diff`
   - `git log --oneline -10`
2. Resolve the target branch from `--target`; default to `master` if not specified.
3. Compare the current branch to the target:
   - `git log <target>..HEAD --oneline`
   - `git diff <target>...HEAD --stat`
4. Generate a PR title. If `--title` is provided, use it exactly. Otherwise use `[Project/Service/App Name] Summarized description`.
5. Generate a PR description with these sections:
   - `## Summary`
   - `## Key Changes`
   - `## Impact`
   - `## Risk & Mitigation` only when applicable
   - `## Validation` only when applicable
6. If there are no commits to push, tell the user and stop.
7. If the branch is not pushed, push it with `git push -u origin <branch>`.
8. Create the PR with Azure CLI:

```powershell
az repos pr create --source-branch <current-branch> --target-branch <target> --title "<title>" --description "<generated description>"
```

9. Return the PR URL.

## Copilot notes

- The Claude Code version uses a frontmatter `PostToolUse` hook to capture PR output. Copilot hooks use separate JSON hook configuration, so this skill does not register that hook in frontmatter.
- If an ADO MCP server is available and preferable in the current environment, use the equivalent PR creation tool instead of Azure CLI.
- Do not include Claude-specific coauthor text in the PR body.
