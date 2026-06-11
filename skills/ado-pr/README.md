# Azure DevOps PR Skill

Creates Azure DevOps pull requests with standardized titles and descriptions.

## Prerequisites

- **Azure CLI** — install from the [Microsoft Azure CLI install guide](https://learn.microsoft.com/cli/azure/install-azure-cli):

  ```powershell
  # Windows (PowerShell)
  winget install --id Microsoft.AzureCLI
  ```

  ```sh
  # Linux / macOS / POSIX
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  ```

- **Azure DevOps extension** — install with:

  ```powershell
  # Windows (PowerShell)
  az extension add --name azure-devops
  ```

  ```sh
  # Linux / macOS / POSIX
  az extension add --name azure-devops
  ```

- **Authenticated Azure DevOps session** — sign in with:

  ```powershell
  # Windows (PowerShell)
  az login
  ```

  ```sh
  # Linux / macOS / POSIX
  az login
  ```

## Available Skills

| Marker | Meaning |
|--------|---------|
| ✅ | Supported |
| ❌ | Not supported |
| ⚠️ | Partial support or manual setup required |
| 🛠️ | Planned |

| Skill | Claude Code | Copilot CLI | Description | Notes |
|-------|-------------|-------------|-------------|-------|
| `/ado-pr` | ✅ | ✅ | Create a pull request in Azure DevOps with standardized formatting | Shared skill. |

## Installation

Install the skill with the sync scripts.

- **Claude project-level** (one project): `<project-root>\.claude\skills\`
- **Claude user-level** (all projects): `~\.claude\skills\`
- **Copilot project-level** (one project): `<project-root>\.github\skills\`
- **Copilot user-level** (all projects): `~\.copilot\skills\`

```powershell
# Windows (PowerShell)
.\bin\seiji-claude-sync-skills.ps1
.\bin\seiji-copilot-sync-skills.ps1
```

```sh
# Linux / macOS / POSIX
./bin/seiji-claude-sync-skills
# POSIX Copilot sync is tracked by #21.
```

For project-level installs, the skills are available to anyone who clones the target project. Project-level sync support is not documented here yet.

## Usage

```
# Create a PR with an auto-generated title and target
/ado-pr

# Target a specific branch
/ado-pr --target develop

# Use a custom title
/ado-pr --title "[ServiceName] Add authentication middleware"

# Create a draft PR when supported
/ado-pr --draft
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--target` | No | Remote default branch, then `main` | Target branch for the PR |
| `--title` | No | Generated from branch commits and changed files | Custom PR title |
| `--draft` | No | off | Create a draft PR when supported by the available Azure DevOps PR creation command |

## PR Format

The skill generates a title in the form `[Project/Service/App Name] Description`, then creates a PR description with these sections:

```markdown
## Summary
## Key Changes
## Impact
## Risk & Mitigation
## Validation
```

`Risk & Mitigation` and `Validation` are included only when they apply.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| PR creation fails | Verify Azure CLI, the Azure DevOps extension, authentication, repository permissions, and the target branch. |
| Title is too generic | Re-run with `--title` and provide the exact title to use. |
| Draft flag is unavailable | Create the PR normally, then mark it draft in the Azure DevOps UI if your server supports drafts. |
