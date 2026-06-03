---
name: ado-pr-status
description: View all Azure DevOps PRs linked to Claude Code sessions
argument-hint: "[--all]"
---

# Azure DevOps PR Status

Lists all Azure DevOps pull requests that have been tracked and linked to Claude Code sessions.

## Usage

```
/ado-pr-status [--all]
```

## Parameters

- `--all`: Show PRs from all repositories (default: current repository only)

## Instructions

When this skill is invoked:

Execute this bash command:

```bash
DB="$HOME/.claude/ado-pr-sessions.json"
SHOW_ALL=false

# Check for --all flag
if [ "$1" == "--all" ]; then
  SHOW_ALL=true
fi

# Check if database exists
if [ ! -f "$DB" ]; then
  echo "No Azure DevOps PRs tracked yet."
  echo ""
  echo "PRs created with /ado-pr will be automatically tracked here."
  exit 0
fi

# Get current repository name (if showing only current repo)
if [ "$SHOW_ALL" == "false" ]; then
  REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
  REPO_NAME=$(basename "$REPO_URL" .git 2>/dev/null || echo "")

  if [ -z "$REPO_NAME" ]; then
    echo "❌ Not in a git repository. Use --all to see PRs from all repositories."
    exit 1
  fi

  echo "=== Azure DevOps PRs for $REPO_NAME ==="
  echo ""

  # Check if repository has any PRs
  HAS_PRS=$(jq -r --arg repo "$REPO_NAME" '.[$repo] // {} | length' "$DB")

  if [ "$HAS_PRS" == "0" ]; then
    echo "No PRs tracked for this repository yet."
    echo ""
    echo "Use /ado-pr to create a tracked PR."
    exit 0
  fi

  # List PRs for current repository
  jq -r --arg repo "$REPO_NAME" '
    .[$repo] // {} |
    to_entries |
    sort_by(.key | tonumber) |
    reverse |
    .[] |
    "PR #\(.key)\n  Branch:  \(.value.branch)\n  Created: \(.value.created_at)\n  Session: \(.value.session_id)\n  URL:     \(.value.pr_url)\n"
  ' "$DB"
else
  echo "=== All Azure DevOps PRs ==="
  echo ""

  # List all PRs from all repositories
  jq -r '
    to_entries |
    .[] |
    "[\(.key)]\n" + (
      .value |
      to_entries |
      sort_by(.key | tonumber) |
      reverse |
      .[] |
      "  PR #\(.key) (\(.value.branch)) - \(.value.created_at)\n  Session: \(.value.session_id)\n  URL: \(.value.pr_url)\n"
    )
  ' "$DB"
fi

echo ""
echo "To resume a session: /ado-resume-pr [PR-NUMBER]"
```

## Examples

Show PRs in current repository:
```
/ado-pr-status
```

Output:
```
=== Azure DevOps PRs for Reno ===

PR #4888994
  Branch:  u/angelseijim/notifcloudconfigs
  Created: 2026-02-05T18:17:24Z
  Session: abc123def456
  URL:     https://o365exchange.visualstudio.com/.../pullrequests/4888994

PR #4888993
  Branch:  u/angelseijim/feature-x
  Created: 2026-02-04T10:30:00Z
  Session: xyz789abc123
  URL:     https://o365exchange.visualstudio.com/.../pullrequests/4888993

To resume a session: /ado-resume-pr [PR-NUMBER]
```

Show PRs from all repositories:
```
/ado-pr-status --all
```

## Notes

- By default, shows PRs only from the current repository
- Use `--all` to see PRs across all your Azure DevOps projects
- Session tracking is local to your machine
- PRs must be created using `/ado-pr` to appear here
