---
name: ado-resume-pr
description: Resume the Claude Code session that created a specific Azure DevOps PR
argument-hint: "[PR-NUMBER]"
---

# Resume Azure DevOps PR Session

Resumes a Claude Code session that was used to create a specific Azure DevOps pull request.

## Usage

```
/ado-resume-pr [PR-NUMBER]
```

## Parameters

- `PR-NUMBER`: The Azure DevOps pull request number to look up

## Instructions

When this skill is invoked:

1. **Detect Current Repository**: Determine which repository the user is in
2. **Look Up Session**: Find the session ID that created this PR
3. **Display Information**: Show PR details and session information
4. **Provide Resume Command**: Give the user the command to resume the session

Execute this bash command:

```bash
PR_NUMBER="$1"
DB="$HOME/.claude/ado-pr-sessions.json"

# Check if database exists
if [ ! -f "$DB" ]; then
  echo "❌ No Azure DevOps PR sessions tracked yet."
  echo "   PRs created with /ado-pr will be automatically tracked."
  exit 1
fi

# Get current repository name
REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
REPO_NAME=$(basename "$REPO_URL" .git 2>/dev/null || echo "")

if [ -z "$REPO_NAME" ]; then
  echo "❌ Not in a git repository or unable to determine repository name"
  exit 1
fi

# Look up the PR in this repository
SESSION_DATA=$(jq -r --arg repo "$REPO_NAME" --arg pr "$PR_NUMBER" \
  '.[$repo][$pr] // empty' "$DB")

if [ -z "$SESSION_DATA" ] || [ "$SESSION_DATA" == "null" ]; then
  echo "❌ PR #$PR_NUMBER not found in repository '$REPO_NAME'"
  echo ""
  echo "Available PRs in this repository:"
  jq -r --arg repo "$REPO_NAME" \
    '.[$repo] // {} | to_entries[] | "  PR #\(.key): \(.value.branch)"' "$DB"
  exit 1
fi

# Extract session information
SESSION_ID=$(echo "$SESSION_DATA" | jq -r '.session_id')
PR_URL=$(echo "$SESSION_DATA" | jq -r '.pr_url')
BRANCH=$(echo "$SESSION_DATA" | jq -r '.branch')
CREATED_AT=$(echo "$SESSION_DATA" | jq -r '.created_at')

# Display information
echo "✓ Found session for PR #$PR_NUMBER"
echo ""
echo "Repository: $REPO_NAME"
echo "Branch:     $BRANCH"
echo "PR URL:     $PR_URL"
echo "Created:    $CREATED_AT"
echo "Session ID: $SESSION_ID"
echo ""
echo "To resume this session, run:"
echo "  claude --resume $SESSION_ID"
```

## Example

```
/ado-resume-pr 4888994
```

Output:
```
✓ Found session for PR #4888994

Repository: Reno
Branch:     u/angelseijim/notifcloudconfigs
PR URL:     https://o365exchange.visualstudio.com/.../pullrequests/4888994
Created:    2026-02-05T18:17:24Z
Session ID: abc123def456

To resume this session, run:
  claude --resume abc123def456
```

## Notes

- This skill looks up PRs in the current repository automatically
- Session tracking is local to your machine
- PRs must be created using `/ado-pr` to be tracked
- Each repository's PRs are tracked separately
