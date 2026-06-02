---
name: ado-task
description: Create, update, complete, and list Azure DevOps work items
---

# ADO Task Manager

Create, update, complete, and list Azure DevOps work items using the configured Azure DevOps MCP server.

## Usage

```copilot
Use the /ado-task skill to create Fix the auth token expiry bug --desc "Tokens expire silently causing 401s" --type Bug
Use the /ado-task skill to mark 78901 done Fixed by adding token refresh logic
Use the /ado-task skill to update 78901 --state Active Started working on this
Use the /ado-task skill to list --filter "state=Active"
```

## Configuration

Read the work-status configuration from `~\.copilot\work-status-config.json` when present. During migration, if that file is missing, also check `~\.claude\work-status-config.json` and tell the user which path was used.

Required keys:

```json
{
  "userEmail": "you@example.com",
  "adoProject": "Your Project",
  "adoTeam": "Your Team"
}
```

## Instructions

When this skill is invoked:

1. Parse the first word of the user's request as the subcommand: `create`, `done`, `update`, `bulk`, or `list`.
2. Use Azure DevOps MCP tools from the configured MCP server. Tool names may be exposed as Copilot MCP names such as `ado/<tool-name>` rather than Claude-style `mcp__ado__<tool-name>` names; use the available equivalent tool.
3. For `create`, resolve the current team iteration, create the work item, assign it to `userEmail` when available, and display the created ID, title, and URL.
4. For `done`, set the work item state to `Closed` first, falling back to `Done` if the work item type does not support `Closed`. Add notes as a comment when provided.
5. For `update`, require at least a state change or notes. Apply the state update and/or add a comment.
6. For `bulk`, parse comma-separated IDs and apply the requested state/comment operation to each item. Report per-item errors rather than hiding partial failures.
7. For `list`, fetch assigned work items, exclude closed/resolved/removed/cut items by default, apply requested filters, sort the result, and display a concise table.

## Error handling

- If configuration is missing, show the expected config JSON and stop.
- If an MCP tool is unavailable, say which Azure DevOps capability is missing and suggest running `/mcp` to configure the ADO server.
- Do not silently ignore failed work item updates; report the item ID and error.
