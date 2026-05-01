#!/usr/bin/env bash
# verify-runner-bash-guard.sh — POSIX variant of the verify-runner PreToolUse hook.
#
# Registered in agents/verify-runner/verify-runner.md's frontmatter. Because
# the harness scopes frontmatter hooks to the owning agent, this script ONLY
# runs while verify-runner is active. No detection / fallback logic needed.
#
# Reads the PreToolUse JSON payload on stdin, extracts the Bash command, and
# either exits 0 (allow) or exits 2 (block) with a reason on stderr per the
# documented Claude Code hook behavior. See the .ps1 sibling for the
# canonical inline notes.
#
# Requires jq for safe JSON parsing.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "verify-runner-bash-guard: 'jq' not found on PATH; allowing." >&2
  exit 0
fi

raw="$(cat || true)"
[ -z "$raw" ] && exit 0

command_str="$(printf '%s' "$raw" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[ -z "$command_str" ] && exit 0

# Reject obvious mutating substrings even when the leading command would
# otherwise match the allowlist (e.g., `git diff && rm -rf .`).
forbidden_subs=( '\brm\b' '\bmv\b' '\bcp\b' '\bcurl\b' '\bwget\b' '>\s*[^&]' '>>\s*' '\|\s*tee\b' '\bdd\b' )
for f in "${forbidden_subs[@]}"; do
  if [[ "$command_str" =~ $f ]]; then
    echo "verify-runner-bash-guard: command contains forbidden substring matching /$f/ -- mutating commands are blocked." >&2
    exit 2
  fi
done

# git branch with -d/-D/-m is mutating
if [[ "$command_str" =~ ^[[:space:]]*git[[:space:]]+branch.*[[:space:]]-(d|D|m)([[:space:]]|$) ]]; then
  echo "verify-runner-bash-guard: 'git branch -d/-D/-m' is mutating and not allowed." >&2
  exit 2
fi

allow_patterns=(
  # Read-only git
  '^[[:space:]]*git[[:space:]]+diff([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+log([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+show([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+status([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+rev-parse([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+ls-files([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+symbolic-ref([[:space:]]|$)'
  '^[[:space:]]*git[[:space:]]+branch([[:space:]]|$)'
  # Coverage tool reads
  '^[[:space:]]*pytest([[:space:]].*)?[[:space:]]--cov([[:space:]]|=|$)'
  '^[[:space:]]*vitest([[:space:]].*)?[[:space:]]--coverage([[:space:]]|$)'
  '^[[:space:]]*jest([[:space:]].*)?[[:space:]]--coverage([[:space:]]|$)'
  '^[[:space:]]*c8([[:space:]]|$)'
  '^[[:space:]]*go[[:space:]]+test([[:space:]].*)?[[:space:]]-cover(profile)?([[:space:]]|=|$)'
  '^[[:space:]]*dotnet[[:space:]]+test([[:space:]].*)?[[:space:]]--collect([[:space:]]|:|$)'
  '^[[:space:]]*cargo[[:space:]]+tarpaulin([[:space:]]|$)'
  '^[[:space:]]*cargo[[:space:]]+llvm-cov([[:space:]]|$)'
  # JSON tool
  '^[[:space:]]*jq([[:space:]]|$)'
)

for p in "${allow_patterns[@]}"; do
  if [[ "$command_str" =~ $p ]]; then exit 0; fi
done

echo "verify-runner-bash-guard: command not in read-only allowlist. Allowed prefixes: read-only git (diff/log/show/status/rev-parse/ls-files/symbolic-ref/branch), coverage-tool reads (pytest --cov, vitest --coverage, jest --coverage, c8, go test -cover, dotnet test --collect, cargo tarpaulin/llvm-cov), and jq." >&2
exit 2
