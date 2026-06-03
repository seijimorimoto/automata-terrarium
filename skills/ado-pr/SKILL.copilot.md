---
name: ado-pr
description: Create a pull request in Azure DevOps with standardized formatting
---

# Azure DevOps Pull Request Creator

Creates a pull request in Azure DevOps with a standardized format.

## Usage

```
/ado-pr [--target BRANCH] [--title "Custom Title"]
```

## Parameters

- `--target`: Target branch (default: master)
- `--title`: Custom PR title (optional, will be auto-generated if not provided)

## Instructions

When this skill is invoked:

1. **Check Git Status**: Run these commands in parallel:
   - `git status` - Check current branch and staged changes
   - `git diff --staged && echo "--- UNSTAGED CHANGES ---" && git diff` - Show all changes
   - `git log --oneline -10` - Show recent commits

2. **Analyze Branch Commits**: Compare current branch to target branch:
   - `git log <target>..HEAD --oneline` - Show commits not in target
   - `git diff <target>...HEAD --stat` - Show summary of changes

3. **Generate PR Content**:
   - Analyze ALL commits that will be included in the PR (not just the latest)
   - Create a PR title following this format if not provided via --title:
     - Format: `[Project/Service/App Name] Summarized description of the changes`
     - Example: `[NotificationServicesCloudSpecific] Add configuration files for each cloud`
     - Example: `[ReadServices] Implement caching layer for tenant metadata`
     - Example: `[EventAuthoringService] Add validation for incident severity levels`
     - Keep the title concise (under 80 characters total)
     - Determine the project/service name from the files changed
   - Generate a PR description using this EXACT format:

```markdown
## Summary
[1-2 paragraphs explaining what this PR does and why]

## Key Changes
- [Bulleted list of the main changes]
- [Be specific about files, features, or components modified]
- [Include technical details where relevant]

## Impact
- [Who/what is affected by these changes]
- [Benefits or improvements delivered]
- [Any important considerations]

## Risk & Mitigation
[Only include this section if there are risks]
- [Potential risks or concerns]
- [How they are mitigated]

## Validation
[Only include if applicable]
- [How these changes were validated]
- [Testing approach or verification steps]
```

4. **Handle Edge Cases**:
   - If no commits to push: inform user and exit
   - If branch not pushed to remote: push with `git push -u origin <branch>`
   - If already at remote: confirm branch is up to date

5. **Create PR**: Execute the Azure CLI command:
```bash
az repos pr create \
  --source-branch <current-branch> \
  --target-branch <target> \
  --title "<title>" \
  --description "$(cat <<'EOF'
<generated description>
EOF
)"
```

If an ADO MCP server is available and preferable in the current environment, use the equivalent PR creation tool instead of Azure CLI.

6. **Return PR URL**: After successful creation, display the PR URL for easy access.

## Runtime Notes

- The Claude Code version uses a skill-frontmatter `PostToolUse` hook to capture PR output. Copilot CLI does not support skill-frontmatter-scoped hooks; Copilot hooks use separate JSON/settings lifecycle configuration, so this skill cannot register that hook in frontmatter.
- Do not include Claude-specific coauthor text in the PR body.

## Important Notes

- ALWAYS analyze ALL commits in the branch, not just the latest commit
- PR titles MUST follow the format: `[Project/Service/App Name] Description`
- Determine the project/service name from the files being changed
- Keep PR titles concise and descriptive (under 80 characters)
- Only include "Risk & Mitigation" and "Validation" sections when applicable
- Use the EXACT section format specified above
- If the user provides a custom title with --title, use it exactly as provided
- Default target branch is "master" for the Reno repository

## Examples

Simple usage:
```
/ado-pr
```

With custom target:
```
/ado-pr --target develop
```

With custom title:
```
/ado-pr --title "[ReadServices] Add authentication middleware for API endpoints"
```

With both:
```
/ado-pr --target develop --title "[ServiceProviders] Refactor data access layer"
```
