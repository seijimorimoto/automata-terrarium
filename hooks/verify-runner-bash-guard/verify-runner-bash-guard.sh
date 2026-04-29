#!/usr/bin/env bash
# verify-runner-bash-guard.sh — POSIX variant of the PreToolUse hook that
# restricts Bash commands inside the `verify-runner` subagent to a read-only
# allowlist. Best-effort: falls back to a no-op (allow) when verify-runner
# context can't be detected. See the .ps1 variant for the canonical inline
# documentation; the behavior here mirrors it.
#
# Requires jq for safe JSON parsing of the hook input.
set -euo pipefail

LOG_DIR="$HOME/.claude/hooks/verify-runner-bash-guard"
PROBE_LOG="$LOG_DIR/probe.log"
OP_LOG="$LOG_DIR/log"
SENTINEL="$LOG_DIR/.fallback-warned"

mkdir -p "$LOG_DIR" 2>/dev/null || true

op_log() {
  local stamp
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s %s\n' "$stamp" "$*" >> "$OP_LOG" 2>/dev/null || true
}

allow() {
  printf '{}\n'
  exit 0
}

deny() {
  local reason="$1"
  jq -nc --arg r "$reason" '{
    decision: "block",
    reason: $r,
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  op_log "jq not found on PATH; allowing"
  allow
fi

raw="$(cat || true)"
if [ -z "$raw" ]; then allow; fi

# One-time probe: log top-level keys
if [ ! -f "$PROBE_LOG" ]; then
  keys="$(printf '%s' "$raw" | jq -r 'keys | join(", ")' 2>/dev/null || echo '<unparseable>')"
  printf 'first-run keys: %s\n' "$keys" > "$PROBE_LOG" 2>/dev/null || true
fi

tool_name="$(printf '%s' "$raw" | jq -r '.tool_name // .toolName // .tool // empty' 2>/dev/null || true)"
[ "$tool_name" = "Bash" ] || allow

command_str="$(printf '%s' "$raw" | jq -r '.tool_input.command // .toolInput.command // .tool_input.cmd // empty' 2>/dev/null || true)"
if [ -z "$command_str" ]; then
  op_log "no Bash command in payload; allowing"
  allow
fi

# Detect verify-runner across plausible field names + env vars
is_vr=0
for k in subagent_type subagentType agent_name agentName agent agent_type agentType; do
  v="$(printf '%s' "$raw" | jq -r --arg k "$k" '.[$k] // empty' 2>/dev/null || true)"
  if [ "$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')" = "verify-runner" ]; then
    is_vr=1; break
  fi
done
if [ "$is_vr" -eq 0 ]; then
  parent_agent_name="$(printf '%s' "$raw" | jq -r '.parent_agent.name // empty' 2>/dev/null || true)"
  if [ "$(printf '%s' "$parent_agent_name" | tr '[:upper:]' '[:lower:]')" = "verify-runner" ]; then is_vr=1; fi
fi
if [ "$is_vr" -eq 0 ]; then
  case "$(printf '%s' "${CLAUDE_SUBAGENT_TYPE:-}" | tr '[:upper:]' '[:lower:]')" in verify-runner) is_vr=1 ;; esac
fi
if [ "$is_vr" -eq 0 ]; then
  case "$(printf '%s' "${CLAUDE_AGENT_NAME:-}" | tr '[:upper:]' '[:lower:]')" in verify-runner) is_vr=1 ;; esac
fi

if [ "$is_vr" -eq 0 ]; then
  if [ ! -f "$SENTINEL" ]; then
    : > "$SENTINEL" 2>/dev/null || true
    op_log "FALLBACK: verify-runner context not detected in PreToolUse payload; hook is now no-op (allow). Inspect probe.log to see which keys the harness exposes."
  fi
  allow
fi

# We're inside verify-runner — apply allowlist
forbidden_subs=( '\brm\b' '\bmv\b' '\bcp\b' '\bcurl\b' '\bwget\b' '>\s*[^&]' '>>\s*' '\|\s*tee\b' '\bdd\b' )
for f in "${forbidden_subs[@]}"; do
  if [[ "$command_str" =~ $f ]]; then
    deny "verify-runner-bash-guard: command contains forbidden substring matching /$f/ -- mutating commands are blocked in verify-runner subagents."
  fi
done

allow_patterns=(
  '^[[:space:]]*git[[:space:]]+diff([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+log([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+show([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+status([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+rev-parse([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+ls-files([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+symbolic-ref([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+branch'   # branch alone or with read-only flags; mutating flags (-d/-D/-m) covered by forbidden_subs check below
  '^[[:space:]]*pytest([[:space:]].*)?[[:space:]]--cov([[:space:]]|=|$)'
  '^[[:space:]]*vitest([[:space:]].*)?[[:space:]]--coverage([[:space:]]|$)'
  '^[[:space:]]*jest([[:space:]].*)?[[:space:]]--coverage([[:space:]]|$)'
  '^[[:space:]]*c8([[:space:]]|$)'
  '^[[:space:]]*go[[:space:]]+test([[:space:]].*)?[[:space:]]-cover(profile)?([[:space:]]|=|$)'
  '^[[:space:]]*dotnet[[:space:]]+test([[:space:]].*)?[[:space:]]--collect([[:space:]]|:|$)'
  '^[[:space:]]*cargo[[:space:]]+tarpaulin([[:space:]]|$)'
  '^[[:space:]]*cargo[[:space:]]+llvm-cov([[:space:]]|$)'
  '^[[:space:]]*jq([[:space:]]|$)'
)

# Extra check: git branch with -d/-D/-m is forbidden
if [[ "$command_str" =~ ^[[:space:]]*git[[:space:]]+branch.*[[:space:]]-(d|D|m)([[:space:]]|$) ]]; then
  deny "verify-runner-bash-guard: 'git branch -d/-D/-m' is mutating and not allowed."
fi

matched=0
for p in "${allow_patterns[@]}"; do
  if [[ "$command_str" =~ $p ]]; then matched=1; break; fi
done

if [ "$matched" -eq 0 ]; then
  deny "verify-runner-bash-guard: command not in read-only allowlist. Allowed prefixes: read-only git (diff/log/show/status/rev-parse/ls-files/symbolic-ref/branch), coverage-tool reads (pytest --cov, vitest --coverage, jest --coverage, c8, go test -cover, dotnet test --collect, cargo tarpaulin/llvm-cov), and jq."
fi

allow
